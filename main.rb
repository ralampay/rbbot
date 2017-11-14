require 'rubygems'
require 'bundler/setup' 
require 'httparty'
require 'json'
require 'base64'
require 'cgi'

config      = JSON.parse(File.read("config.json"))
market_coin = config["market_coin"]
market_qty  = config["market_qty"]
base_coin   = config["base_coin"]
market      = "#{base_coin}-#{market_coin}"
api_key     = config["api_key"]
api_secret  = config["api_secret"]
target      = config["target"].to_f
last_sell   = config["last_sell"].to_f

puts "Market: #{market}"

while true do
  url_ticker  = "#{config["base_url"]}/#{config["api_version"]}#{config["endpoints"]["ticker"]}"
  response    = HTTParty.get(
                  url_ticker,
                  query: {
                    market: market
                  }
                )

  result      = response["result"]

  r_bid       = result["Bid"].to_f
  r_ask       = result["Ask"].to_f
  r_last      = result["Last"].to_f

  net_diff    = ((r_bid - last_sell) / last_sell)
  net_diff_f  = (net_diff * 100).round(3)

  url_balance = "#{config["base_url"]}/#{config["api_version"]}#{config["endpoints"]["balance"]}?apikey=#{api_key}&currency=#{market_coin}&nonce=#{Time.now.to_i}"
  sign        = OpenSSL::HMAC.hexdigest('sha512', api_secret.encode("ASCII"), url_balance.encode("ASCII"))

  response    = HTTParty.get(
                  url_balance,
                  headers: {
                    apisign: sign
                  }
                )
               
  result      = response["result"]
  balance     = result["Balance"]

  puts "#{Time.now.strftime("%b %d, %Y %H:%M")}\tBid: #{r_bid}\tAsk: #{r_ask}\tLast: #{r_last}\tLast Sell: #{last_sell}\tNet: #{net_diff_f}%\tBal: #{balance}"

  if net_diff >= target
    # Perform a sell operation
    puts "SELL NOW!!!"

    url_orderbook = "#{config["base_url"]}/#{config["api_version"]}#{config["endpoints"]["orderbook"]}"
    response      = HTTParty.get(
                      url_orderbook,
                      query: {
                        market: market,
                        type: "buy"
                      }
                    )

    if response["success"] == true
      result  = response["result"]

      temp_quantity = 0
      temp_rate     = 0

      result.each do |order_book_record|
        if order_book_record["Rate"] > temp_rate
          temp_rate     = order_book_record["Rate"]
          temp_quantity = order_book_record["Quantity"]
        end
      end

      if temp_rate > 0 && temp_quantity > market_qty && market_qty > 0
        puts "Best Deal --> Rate: #{temp_rate} Qty: #{temp_quantity}"

        url_sell = "#{config["base_url"]}/#{config["api_version"]}#{config["endpoints"]["sell"]}?apikey=#{api_key}&nonce=#{Time.now.to_i}&market=#{market}&quantity=#{market_qty}&rate=#{temp_rate}"
        sign        = OpenSSL::HMAC.hexdigest('sha512', api_secret.encode("ASCII"), url_sell.encode("ASCII"))

        response    = HTTParty.get(
                        url_sell,
                        headers: {
                          apisign: sign
                        }
                      )

        if response["success"] == true
          puts "Sold #{market_qty} of #{market_coin} at a rate of #{temp_rate}!"
          market_coin = 0
        else
          puts "Something went wrong"
          puts response
        end
      end
    else
      puts "Something went wrong when querying orderbook"
      puts response
    end
  end

  sleep 10
end









