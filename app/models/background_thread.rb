module MazeCraze
  class BackgroundThread
    include MazeCraze::Queryable

    @all = []

    class << self
      attr_accessor :all
    end

    def self.thread_from_id(thread_id)
      all.each do |background_thread| 
        return background_thread if background_thread.id == thread_id
      end
      # sometimes the thread doesn't exist so all is returned
      nil
    end

    # delete this
    # def self.thread_from_thread(thread)
    #   all.each do |background_thread|
    #     return background_thread if background_thread.thread == thread
    #   end
    #   nil
    # end

    def self.thread_details(worker_id)
      details = []
      all.each do |background_thread|
        next unless background_thread.background_worker_id == worker_id
        details << { id: background_thread.id,
                     job_id: background_thread.background_job_id,
                     status: background_thread.thread.alive?,
                     mode: background_thread.mode }
      end
      details
    end

    def self.kill_all_threads
      all.each(&:kill_thread)
    end

    attr_reader :thread, :background_worker_id
    attr_accessor :id, :background_job_id, :status, :mode

    def initialize(background_worker_id, thread)
      self.class.all << self
      @thread = thread
      @background_worker_id = background_worker_id
      @status = thread.alive? ? 'alive' : 'dead'
      @mode = 'waiting'
      save!
    end

    def kill_thread
      Thread.kill(thread)
      update_thread_status_to_dead
      MazeCraze::BackgroundWorker.worker.threads.delete(thread)
      self.class.all.delete(self)
    end

    def save!
      sql = 'INSERT INTO background_threads (background_worker_id, status) VALUES ($1, $2) RETURNING id;'
      self.id = query(sql, background_worker_id, status).first['id']
    end

    def update_thread_status_to_dead
      self.status = 'dead'
      sql = "UPDATE background_threads SET status = $1, updated = $2 WHERE id = $3;"
      query(sql, status, 'NOW()', id)
    end
  end
end
