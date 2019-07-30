module MazeCraze
  class BackgroundWorker
    extend MazeCraze::Queryable
    include MazeCraze::Queryable

    MIN_THREADS = 1
    MAX_THREADS = 10

    # Each BackgroundWorker object creates a new instance of the Queue object
    # which implements multi-producer, multi-consumer queues. Each BackgroundWorker
    # instance can run many threads at a time -- the number of threads that can be
    # run is dependent upon the operating system and the machine that is running this
    # application and the number of threads you enable the application to instantiate,
    # which is a setting on the Settings page in the administrative area. We use an
    # instance of the Queue object it to pass jobs to threads when they become available.
    # We only allow one instance of BackgroundWorker to exist at a time to optimize the
    # use of threads that are available for several reasons:

    # 1) If more than one BackgroundWorker instance existed at the same time, we would
    # have to implement a way to balance the jobs that are pushed to each
    # BackgroundWorker's queue, which would be difficult to do because we would have to
    # estimate how long each job would take to be processed (some jobs can be processed
    # quickly, in a matter of seconds, while some jobs can take hours to complete).

    # 2) Each BackgroundWorker instance tries to instantiate the number of threads that
    # are allowed to run (again, this is a setting on the Settings page in the
    # adminstrative area). If, for example, a machine can only run 4 threads, having more
    # than one instance of BackgroundWorker would be pointless -- the application would
    # not even be able to instantiate the additional threads.

    @worker = nil

    class << self
      attr_accessor :worker
    end

    def self.active?
      return false if worker.nil?

      worker.threads.each do |thread|
        return true if thread.alive? && worker.job_queue_open?
      end

      false
    end

    def self.number_of_threads
      sql = 'SELECT integer_value FROM settings WHERE name = $1;'
      query(sql, 'number_of_threads').first['integer_value'].to_i
    end

    def self.update_number_of_threads(number)
      sql = 'UPDATE settings SET integer_value = $1, updated = $2 WHERE name = $3;'
      query(sql, number, 'NOW()', 'number_of_threads')
    end

    def self.start
      BackgroundWorker.new
    end

    def self.stop
      MazeCraze::BackgroundThread.kill_all_threads
      MazeCraze::BackgroundJob.undo_running_jobs
      MazeCraze::BackgroundJob.reset_running_jobs
      BackgroundWorker.kill_worker
    end

    def self.kill_worker
      worker.kill_worker
      self.worker = nil
    end

    attr_reader :job_queue
    attr_accessor :id, :number_of_threads, :threads, :deleted_jobs

    def initialize
      self.class.worker = self
      @number_of_threads = self.class.number_of_threads
      @threads = []
      @deleted_jobs = []
      @job_queue = Queue.new
      save!
      enqueue_jobs
      work
    end

    def enqueue_jobs
      MazeCraze::BackgroundJob.each_job { |job| enqueue_job(job) if job.status == 'queued' }
    end

    def enqueue_job(job)
      job_queue << job
      sql = 'UPDATE background_jobs SET background_worker_id = $1, updated = $2 WHERE id = $3;'
      query(sql, id, 'NOW()', job.id)
    end

    def dead?
      return false if threads.any?(&:alive?) && job_queue_open?
      true
    end

    def job_queue_open?
      !job_queue.closed?
    end

    def delete_job(job_id)
      deleted_jobs << job_id
    end

    # REFACTOR THIS
    def kill_specific_job(thread_id, job_id)
      MazeCraze::BackgroundThread.thread_from_id(thread_id).kill_thread

      job = MazeCraze::BackgroundJob.job_from_id(job_id)
      job.reset
      job.undo
      enqueue_job(job)
      new_thread
    end

    def kill_worker
      job_queue.close
      yield if block_given? # do I need this?
      update_worker_status('dead')
    end

    def retire_worker
      kill_worker do
        threads.each(&:join)
        threads.each do |thread|
          MazeCraze::BackgroundThread.each_background_thread do |background_thread|
            if background_thread.thread == thread
              background_thread.kill_thread
            end
          end
          threads.delete(thread)
        end
      end
    end

    # REFACTOR THIS
    def new_thread
      threads << thread = Thread.new do
        if thread.nil?
          threads.delete(nil)
          next
        end

        background_thread = MazeCraze::BackgroundThread.new(id, thread)

        while job_queue_open?
          background_thread.mode = Thread.current[:mode] = 'waiting'
          background_thread.background_job_id = nil
          job = wait_for_job

          if job && deleted_jobs.include?(job.id)
            deleted_jobs.delete(job.id)
            next
          elsif job
            background_thread.mode = Thread.current[:mode] = 'processing'
            background_thread.background_job_id = job.id
            job.update_job_is_running(background_thread.id)
            MazeCraze::BackgroundJob.queued_count -= 1
            MazeCraze::BackgroundJob.update_queue_orders
            job.run
          end
        end
      end

      retire_worker unless job_queue_open?
    end

    private

    def save!
      sql = "INSERT INTO background_workers DEFAULT VALUES RETURNING id;"
      self.id = query(sql).first['id']
    end

    def update_worker_status(status)
      sql = "UPDATE background_workers SET status = $1, updated = $2 WHERE id = $3;"
      query(sql, status, 'NOW()', id)
    end

    def work
      number_of_threads.times { new_thread }
    end

    def jobs_in_job_queue?
      !job_queue.empty?
    end

    def wait_for_job
      job_queue.pop(false)
    end
  end
end
