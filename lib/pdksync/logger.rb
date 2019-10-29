# frozen_string_literal: true

require 'logger'

class String
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def fatal
    red
  end

  def yellow
    colorize(33)
  end

  def light_blue
    colorize(36)
  end
end

module PdkSync
  class Logger
    def self.warn(message)
      logger.warn(message)
    end

    def self.info(message)
      logger.info(message)
    end

    def self.debug(message)
      logger.debug(message)
    end

    def self.fatal(message)
      logger.fatal(message)
    end

    def self.crit(message)
      logger.error(message)
    end

    def self.log_file
      if ENV['PDKSYNC_LOG_FILENAME'] && File.exist?(ENV['PDKSYNC_LOG_FILENAME'])
        ENV['PDKSYNC_LOG_FILENAME']
      else
        STDOUT
      end
    end

    def self.logger(file = PdkSync::Logger.log_file)
      @logger ||= begin
        log = ::Logger.new(file)
        log.level = log_level
        log.progname = 'PdkSync'
        log.formatter = proc do |severity, datetime, progname, msg|
          if PdkSync::Logger.log_file == STDOUT
            "#{severity} - #{progname}: #{msg}\n".send(color(severity))
          else
            "#{datetime} #{severity} - #{progname}: #{msg}\n".send(color(severity))
          end
        end
        log
      end
    end

    def logger
      @logger ||= PdkSync::Logger.logger
    end

    def self.color(severity)
      case severity
      when ::Logger::Severity::WARN, 'WARN'
        :yellow
      when ::Logger::Severity::INFO, 'INFO'
        :green
      when ::Logger::Severity::FATAL, 'FATAL'
        :fatal
      when ::Logger::Severity::ERROR, 'ERROR'
        :fatal
      when ::Logger::Severity::DEBUG, 'DEBUG'
        :light_blue
      else
        :green
      end
    end

    def self.log_level
      level = ENV['LOG_LEVEL'].downcase if ENV['LOG_LEVEL']
      case level
      when 'warn'
        ::Logger::Severity::WARN
      when 'fatal'
        ::Logger::Severity::FATAL
      when 'debug'
        ::Logger::Severity::DEBUG
      when 'info'
        ::Logger::Severity::INFO
      when 'error'
        ::Logger::Severity::ERROR
      else
        ::Logger::Severity::INFO
      end
    end
  end
end
