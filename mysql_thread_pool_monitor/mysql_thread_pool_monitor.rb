# Monitors MySQL thread pool plugin
#
# Charts the rate-of-change of the important fields from the INFORMATION_SCHEMA TP_THREAD_GROUP_STATS Table
# Sudden spikes indicate abnormal events esp. regarding the *_WAITS fields
#
# http://dev.mysql.com/doc/refman/5.5/en/thread-pool-plugin.html
# http://dev.mysql.com/doc/refman/5.5/en/thread-pool-tuning.html

# The INFORMATION_SCHEMA TP_THREAD_GROUP_STATS Table

# This table reports statistics per thread group. There is one row per group. The table has these columns:

# TP_GROUP_ID
#  The thread group ID. This is a unique key within the table.

# CONNECTIONS_STARTED
#  The number of connections started.

# CONNECTIONS_CLOSED
#  The number of connections closed.

# QUERIES_EXECUTED
#  The number of statements executed. This number is incremented when a statement starts executing, not when it finishes.

# QUERIES_QUEUED
#  The number of statements received that were queued for execution. This does not count statements that the thread group was able to begin executing immediately without queuing, which can happen under the conditions described in Section 7.11.6.2, “Thread Pool Operation”.

# THREADS_STARTED
#  The number of threads started.

# PRIO_KICKUPS
#  The number of statements that have been moved from low-priority queue to high-priority queue based on the value of the thread_pool_prio_kickup_timer system variable. If this number increases quickly, consider increasing the value of that variable. A quickly increasing counter means that the priority system is not keeping transactions from starting too early. For InnoDB, this most likely means deteriorating performance due to too many concurrent transactions..

# STALLED_QUERIES_EXECUTED
#  The number of statements that have become defined as stalled due to executing for a time longer than the value of the thread_pool_stall_limit system variable.

# BECOME_CONSUMER_THREAD
#  The number of times thread have been assigned the consumer thread role.

# BECOME_RESERVE_THREAD
#  The number of times threads have been assigned the reserve thread role.

# BECOME_WAITING_THREAD
#  The number of times threads have been assigned the waiter thread role. When statements are queued, this happens very often, even in normal operation, so rapid increases in this value are normal in the case of a highly loaded system where statements are queued up.

# WAKE_THREAD_STALL_CHECKER
#  The number of times the stall check thread decided to wake or create a thread to possibly handle some statements or take care of the waiter thread role.

# SLEEP_WAITS
#  The number of THD_WAIT_SLEEP waits. These occur when threads go to sleep; for example, by calling the SLEEP() function.

# DISK_IO_WAITS
#  The number of THD_WAIT_DISKIO waits. These occur when threads perform disk I/O that is likely to not hit the file system cache. Such waits occur when the buffer pool reads and writes data to disk, not for normal reads from and writes to files.

# ROW_LOCK_WAITS
#  The number of THD_WAIT_ROW_LOCK waits for release of a row lock by another transaction.

# GLOBAL_LOCK_WAITS
#  The number of THD_WAIT_GLOBAL_LOCK waits for a global lock to be released.

# META_DATA_LOCK_WAITS
#  The number of THD_WAIT_META_DATA_LOCK waits for a metadata lock to be released.

# TABLE_LOCK_WAITS
#  The number of THD_WAIT_TABLE_LOCK waits for a table to be unlocked that the statement needs to access.

# USER_LOCK_WAITS
#  The number of THD_WAIT_USER_LOCK waits for a special lock constructed by the user thread.

# BINLOG_WAITS
#  The number of THD_WAIT_BINLOG_WAITS waits for the binary log to become free.

# GROUP_COMMIT_WAITS
#  The number of THD_WAIT_GROUP_COMMIT waits. These occur when a group commit must wait for the other parties to complete their part of a transaction.

# FSYNC_WAITS
#  The number of THD_WAIT_SYNC waits for a file sync operation.


require 'time'
require 'date'

class MysqlThreadPoolMonitor < Scout::Plugin

  needs 'mysql'

  OPTIONS=<<-EOS
  host:
    name: Host
    notes: The host to monitor
    default: 127.0.0.1
  port:
    name: Port
    notes: The port number on the host
    default: 3306
  username:
    name: Username
    notes: The MySQL username to use
    default: root
  password:
    name: Password
    notes: The password for the mysql user
    default:
    attributes: password
  EOS

  HEADERS_TO_TRACK_RATE_OF = %w{CONNECTIONS_STARTED CONNECTIONS_CLOSED QUERIES_QUEUED THREADS_STARTED PRIO_KICKUPS STALLED_QUERIES_EXECUTED BECOME_CONSUMER_THREAD BECOME_RESERVE_THREAD BECOME_WAITING_THREAD WAKE_THREAD_STALL_CHECKER SLEEP_WAITS DISK_IO_WAITS ROW_LOCK_WAITS GLOBAL_LOCK_WAITS META_DATA_LOCK_WAITS TABLE_LOCK_WAITS USER_LOCK_WAITS BINLOG_WAITS GROUP_COMMIT_WAITS FSYNC_WAITS}

  SELECT_THREAD_GROUP_STATS = "SELECT * FROM information_schema.TP_THREAD_GROUP_STATS"

  def build_report
    begin
      connection = Mysql.new(option(:host) || "localhost", option(:username) || "root", option(:password), nil, option(:port).to_i)
      result = connection.query(SELECT_THREAD_GROUP_STATS)
      thread_group_stats = fetch_all_rows_as_hash(result)
      if thread_group_stats.length > 0 then
        sum_counts = {}
        thread_group_count = thread_group_stats.length
        thread_group_stats.each { |row|
          HEADERS_TO_TRACK_RATE_OF.each { |tracked_header|
            tracked_value = row[tracked_header].to_i
            if sum_counts[tracked_header] then
              sum_counts[tracked_header] += tracked_value
            else
              sum_counts[tracked_header] = tracked_value
            end
          }
        }

        sum_counts.each { |key, value|
          counter("#{key.downcase}_rate_avg", (value.to_f / thread_group_count.to_f).to_i, :per => :minute, :round => true)
        }
      end
    rescue Mysql::Error => e
      if e.to_s.include?("Unknown table 'tp_thread_group_stats'") then
        error("MySQL thread pool plugin not installed", e.to_s)
      else
        error("Unable to connect to MySQL", e.to_s)
      end
    end
  end

private

  def fetch_all_rows_as_hash(result)
    rows = []
    while row = result.fetch_hash
      rows << row
    end
    rows
  end

end
