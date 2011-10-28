class OpSourceCloudFiles < Scout::Plugin
  needs 'net/http'                          
  needs 'rexml/document'
                
  OPTIONS=<<-EOS
  username:                           
    name: Account Username
  password:               
    name: Account Password
    attributes: password
  EOS
  
  CLOUD_FILES_URI="https://cf-na-east-01.opsourcecloud.net/v2/account"
  
  def build_report                                           
    uri = URI.parse(CLOUD_FILES_URI)
    response = http(uri).request(request(uri.path))
    report = report_from_info(REXML::Document.new(response.body))
    report(report)
  end
  
  private
  
  def report_from_info(info)
    report = {}       
      
    ['bandwidth', 'storage'].each do |c|
      info.root.each_element("/account-info/#{c}/*") do |e| 
        report["#{c}_#{e.name}".to_sym] = mb(e.text)
      end
    end
    
    report[:bandwidth_percent_used] = percent_used(report[:bandwidth_total], report[:bandwidth_allocated])
    report[:storage_percent_used] = percent_used(report[:storage_used], report[:storage_allocated])
    report
  end
  
  def percent_used(used, allocated)                                                          
    (used / allocated * 100).ceil
  end
                 
  def headers
    {'x-client-specification' => '2'}
  end
  
  def http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http
  end                        

  def request(path)
    req = Net::HTTP::Get.new(path, headers)
    req.basic_auth(option('username'), option('password'))
    req
  end
  
  def mb(amount)
    amount.to_f / 1024**2
  end
end