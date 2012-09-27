# Reports number of ready (visible) and unacknowledged (invisible) messages
# in the specified queue.
#
# Steve Ims (steve_ims@yahoo.com)
class AmazonSqsStats < Scout::Plugin
  needs 'rubygems'
  needs 'aws-sdk'

  OPTIONS = <<-EOS
    queue:
      name: Queue Name
      notes: Name of the SQS queue
    access_key:
      name: AWS Access Key
      notes: Your Amazon Web Services access key (20-char alphanumeric)
    secret_key:
      name: AWS Secret
      notes: Your Amazon Web Services secret key (40-char alphanumeric)
  EOS
  
  def init
    @queue = option('queue').to_s.strip
    if @queue.empty?
      return error('queue cannot be empty')
    end

    @access_key = option('access_key').to_s.strip
    if @access_key.empty?
      return error('access_key cannot be empty')
    end
    
    @secret_key = option('secret_key').to_s.strip
    if @secret_key.empty?
      return error('secret_key cannot be empty')
    end

    nil
  end
  
  # Scout method
  def build_report
    return if init()

    # http://docs.amazonwebservices.com/AWSRubySDK/latest/frames.html
    sqs = AWS::SQS.new(
      :access_key_id => @access_key,
      :secret_access_key => @secret_key)

    results = {}
    results['Messages Ready'] = sqs.queues.named(@queue).visible_messages
    results['Messages Unacked'] = sqs.queues.named(@queue).invisible_messages

    report( results )
  end
end
