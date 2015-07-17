# simple monitor for Amazon's Data Pipeline service. Fetches your
# pipelines, checks the healthStatus string, and converts them to integers.
# written by Patrick O'Brien (pobrien@goldstar.com) on 2015-07-01.

class AwsDatapipelineStatus < Scout::Plugin
  needs 'aws-sdk'

  HEALTHY   = 0
  ERROR     = 1
  OTHER     = 2

  OPTIONS=<<-EOS
    awskey:
      name: AWS Access Key
      notes: Your Amazon Web Services Access key. 20-char alphanumeric, looks like 022QF06E7MXBSH9DHM02
    awssecret:
      name: AWS Secret
      notes: Your Amazon Web Services Secret key. 40-char alphanumeric, looks like kWcrlUX5JEDGMLtmEENIaVmYvHNif5zBd9ct81S
    awsregion:
      name: AWS Region
      notes: The AWS Region where your pipelines are defined.
    pipelines:
      name: Pipelines to check status for
      notes: A comma separated list of pipeline names (not IDs) to monitor. This has a maximum of 20 entries, anything over will throw an error. Any entries here that are not found in datapipeline will be silently dropped.
  EOS

  def build_report
    require 'aws-sdk'

    # check to make sure we have at least one pipeline to check.
    if option(:pipelines).nil?
      error("at least one pipeline is required for this plugin.")
    end

    # force 20 pipeline limit
    pipeline_count = option(:pipelines).split(",").count
    if pipeline_count > 20
      error("you specified #{pipeline_count} pipelines, which is above the limit of 20.")
    end

    # set aws credentials
    aws_credentials = Aws::Credentials.new(
      option(:awskey),
      option(:awssecret)
    )

    # create 'datapipeline' object
    datapipeline = Aws::DataPipeline::Client.new(
      region: option(:awsregion),
      credentials: aws_credentials
    )

    # get current defined pipelines by name, and toss their name and ids
    # into pipeline_list.
    pipeline_list = {}
    datapipeline.list_pipelines.pipeline_id_list.each do |pipeline|
      if option(:pipelines).split(",").include?(pipeline["name"])
        pipeline_list[pipeline["name"]] = pipeline["id"]
      end
    end

    # so, uh, this is gross and I am sorry.
    # the AWS SDK returns a struct which we can sift through to get the @healthStatus.
    # once we have the @healthStatus string value, we'll convert that to an integer.
    # FIXME: this can be done in a single call.
    pipeline_status = {}
    pipeline_list.each_pair do |pipeline_name, pipeline_id|

      health_status = datapipeline.describe_pipelines(
        {pipeline_ids: [pipeline_id]}
      ).pipeline_description_list.first.fields.detect{|f| f.key == '@healthStatus'}

      pipeline_status[pipeline_name] = case health_status.string_value
      when "HEALTHY"
        HEALTHY
      when "ERROR"
        ERROR
      else
        OTHER
      end

    end

   report pipeline_status

  end
end

