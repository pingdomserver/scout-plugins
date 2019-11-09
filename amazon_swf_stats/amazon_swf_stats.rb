# Reports total number of open workflows and totals closed (various status)
# since the last run.
#
# Steve Ims (steve_ims@yahoo.com)
class AmazonSWFStats < Scout::Plugin
  needs 'rubygems'
  needs 'aws-sdk'

  OPTIONS = <<-EOS
    access_key:
      name: AWS Access Key
      notes: Your Amazon Web Services access key (20-char alphanumeric)
    secret_key:
      name: AWS Secret
      notes: Your Amazon Web Services secret key (40-char alphanumeric)
    swf_domain:
      name: SWF Domain
      notes: Simple Workflow domain
    wf_type_name:
      name: Workflow Type
      notes: Workflow type
  EOS
  
  def init
    @access_key = option('access_key').to_s.strip
    if @access_key.empty?
      return error('access_key cannot be empty')
    end
    
    @secret_key = option('secret_key').to_s.strip
    if @secret_key.empty?
      return error('secret_key cannot be empty')
    end

    @swf_domain = option('swf_domain').to_s.strip
    if @swf_domain.empty?
      return error('swf_domain cannot be empty')
    end

    @wf_type_name = option('wf_type_name').to_s.strip
    if @wf_type_name.empty?
      return error('wf_type_name cannot be empty')
    end

    nil
  end
  
  # Scout method
  def build_report
    return if init()

    if @last_run
      AWS.config(
        :access_key_id => @access_key,
        :secret_access_key => @secret_key
      )

      # http://docs.amazonwebservices.com/AWSRubySDK/latest/frames.html
      swf = AWS::SimpleWorkflow.new
      domain = swf.domains[@swf_domain]

      
      # Ensure that the basic keys exist in the cache.
      counts = Hash.new(0)
      [:open,
       :closed,
       :completed,
       :failed,
       :canceled,
       :terminated,
       :continued,
       :timed_out].each do |k|

        counts[k] = 0
      end

      # "open" includes all currently open workflows...
      each_options = {
        :status => :open
      }
      domain.workflow_executions.each( each_options ) do |x|
        if x.workflow_type.name == @wf_type_name
          counts[:open] = counts[:open]+1
        end
      end

      # ... and closed workflows that were started after @last_run
      each_options = {
        :status => :closed,
        :started_after => @last_run
      }
      domain.workflow_executions.each( each_options ) do |x|
        if x.workflow_type.name == @wf_type_name
          counts[:open] = counts[:open]+1
        end
      end

      # Log all closed workflows according to their recorded status.
      # Use #each instead of #count to avoid truncation.
      each_options = {
        :status => :closed,
        :closed_after => @last_run
      }
      domain.workflow_executions.each( each_options ) do |x|
        if x.workflow_type.name == @wf_type_name
          execution_status = x.status
          counts[execution_status] = counts[execution_status]+1
        end
      end

      report( counts )
    end
  end
end
