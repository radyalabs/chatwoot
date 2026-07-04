class Captain::Copilot::AiInvocationLock
  ADVISORY_LOCK_NAMESPACE = 10_203

  def initialize(conversation_id)
    @conversation_id = Integer(conversation_id)
  end

  def with_lock
    connection.execute(lock_sql)
    yield
  ensure
    connection&.execute(unlock_sql)
  end

  private

  def connection
    @connection ||= ActiveRecord::Base.connection
  end

  def lock_sql
    "SELECT pg_advisory_lock(#{ADVISORY_LOCK_NAMESPACE}, #{@conversation_id})"
  end

  def unlock_sql
    "SELECT pg_advisory_unlock(#{ADVISORY_LOCK_NAMESPACE}, #{@conversation_id})"
  end
end
