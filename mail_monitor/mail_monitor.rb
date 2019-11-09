#################################################
# MailMonitor
#
#   Report on sendmail/postfix mail queue lengths
#
# Created by dbrown 2015-04-28
# Updated by Matt Chesler 2016-04-06
#################################################

class MailMonitor < Scout::Plugin
  attr_accessor :total, :active, :deferred, :hold

  OPTIONS=<<-EOS
    mail_binary:
      name: Mail Binary
      default: postqueue,sendmail,mailq
      notes: Command to view mail queues without any arguments, e.g. postqueue, sendmail, or mailq
  EOS

  def bin_options
    error("'mail_binary' option not provided") unless option(:mail_binary) && !option(:mail_binary).to_s.empty?

    @bin_options ||= option(:mail_binary).to_s.split(',')
  end

  def mail_binary
    @mail_binary ||= bin_options.reverse.reduce(nil) do |out, b|
      out if out
      e = `which #{b} 2>/dev/null`.chomp
      e if $? == 0
    end
  end

  def mail_bin

    return case
    when mail_binary == nil
      error("mail binary cannot be found for #{bin_options.join(', ')}")
      ""
    when mail_binary.match(/sendmail/)
      mail_binary + " -bp"
    when mail_binary.match(/postqueue/)
      mail_binary + " -p"
    else
      mail_binary
    end
  end

  def execute_command
    begin
      output = `#{mail_bin} 2>&1`
      exit_code = $?.to_i
    rescue StandardError => e
      error(e)
      exit
    end

    { :exit_code => exit_code, :output => output }
  end

  def parse_output(results)

    @total = @active = @deferred = @hold = 0

    if results[:exit_code] != 0
      error("Bad exit code from '#{mail_bin}'", results[:output].chomp)
    else
      results[:output].split(/\n/).each do |line|
        if line.match(/Mail queue is empty/)
          @total = 0
        elsif match_data = line.match(/\A[a-z0-9]+(?<status>\*|\!)?\W+\d+\W+\w{3}\W+\w{3}\W+\d{1,2}\W+\d{2}:\d{2}:\d{2}/i)
          @total += 1
          @active += 1 if match_data[:status] == '*'
          @hold += 1 if match_data[:status] == "!"
          @deferred += 1 if match_data[:status] == nil
        end
      end
    end
  end

  def build_report()
    parse_output(execute_command)

    report(
      :total    => @total,
      :active   => @active,
      :hold     => @hold,
      :deferred => @deferred
    )
  end
end
