require 'rubygems'
require 'bundler/setup' 
require 'httparty'
require 'json'
require 'base64'
require 'cgi'

config      = JSON.parse(File.read("config.json"))
my_coins    = config["my_coins"]
base_coin   = config["base_coin"]
api_key     = config["api_key"]
api_secret  = config["api_secret"]

while true do
  total_base_coin = 0
  usdt_conversion = 0

  my_coins.each do |market_coin|
    market      = "#{base_coin}-#{market_coin}"
    if market_coin == base_coin
      market  = "USDT-#{base_coin}"
    end

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

    if market_coin == base_coin
      usdt_conversion = r_last
    end

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

    sub_total   = r_last * balance

    if market_coin == base_coin
      sub_total = balance * 1
    end

    total_base_coin += sub_total
  end

  usdt_value  = total_base_coin * usdt_conversion

  puts "TOTAL: #{total_base_coin} #{base_coin} USDT: #{usdt_value}"

  sleep(5)
end
