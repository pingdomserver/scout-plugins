class HerokuDataclipPlugin < Scout::Plugin
  OPTIONS=<<-EOS
    dataclip_ids:
      default: "" # a comma-delimited list of dataclip IDs (the string of letters from the url) which return ONLY ONE FIELD AND ROW each
  EOS

  def build_report
    dataclip_ids = option(:dataclip_ids)
    if dataclip_ids.nil? || dataclip_ids.empty? || dataclip_ids !~ /^[a-z,]+$/
      return error("Invalid or missing option \"dataclip_ids\"",
        "The \"dataclip_ids\" option is required to be a comma-delimited list of dataclip IDs " +
          "(the string of letters from the \"dataclips.heroku.com\" url) " +
          "which return ONLY ONE FIELD AND ROW each " +
          "(e.g. \"SELECT COUNT(*) AS total_count FROM tablename;\".  " +
          "Provided value was \"#{dataclip_ids}\""
      )
    end
    dataclip_ids = dataclip_ids.split(',')
    dataclip_result_arrays = []
    dataclip_ids.each do |dataclip_id|
      dataclip_result_arrays << `curl -L https://dataclips.heroku.com/#{dataclip_id}.csv`.split
    end
    dataclip_result_arrays.each do |dataclip_result_array|
      field_name = dataclip_result_array[0].to_sym
      field_value = dataclip_result_array[1]
      report(field_name => field_value)
    end
  end
end
