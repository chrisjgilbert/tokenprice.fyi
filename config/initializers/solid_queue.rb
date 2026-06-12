# Re-open SemanticLogger appenders after forking worker processes.
# Required due to a known issue with rails_semantic_logger and SolidQueue:
# https://github.com/reidmorrison/rails_semantic_logger/issues/237
if defined?(SemanticLogger)
  SolidQueue.on_worker_start { SemanticLogger.reopen }
  SolidQueue.on_dispatcher_start { SemanticLogger.reopen }
  SolidQueue.on_scheduler_start { SemanticLogger.reopen }
end
