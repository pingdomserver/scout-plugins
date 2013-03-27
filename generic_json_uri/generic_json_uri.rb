class GenericJsonUri < Scout::Plugin
  needs 'json', 'open-uri'
  require 'json'
  require 'open-uri'
  
  OPTIONS=<<-EOS
    url: 
      name: URL
      notes: Full URL to the JSON end point you want to query.  Could be a path on the server.
    username:
      notes: Username for basic http auth.
    password: 
      notes: Password for the username.
  EOS
  
  def build_report
    if option(:username) && option(:password) 
      response = nil
      open option(:url), :http_basic_authentication => [option(:username), option(:password)] do |io|
        response = io.read
      end
    else
      response = open(option(:url)).read
    end
    obj = JSON.parse(response)
    report(obj)
  rescue Exception => e
    return error("Error getting JSON", e.message)
  end
  
end