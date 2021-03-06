class Card
  module Set
    # Events are the building blocks of the three transformative card actions: _create_, _update_, and _delete_. (The fourth kind of action, _read_, does not transform cards, and is associated with {Card::Format views}, not events).
    #
    # Whenever you create, update, or delete a card, the card goes through three phases:
    #   * __validation__ makes sure all the data is in order
    #   * __storage__ puts the data in the database
    #   * __integration__ deals with any ramifications of those changes
    #
    #
    class Event
      module Api
        def event event, stage_or_opts={}, opts={}, &final
          Event.new(event, stage_or_opts, opts, self, &final).register
        end
      end

      CONDITION_OPTIONS = {
        on: %i[create update delete save read],
        changed: %i[name content db_content type type_id codename key],
        skip: :allowed,
        trigger: :required,  # the event is only executed if triggered explicitly with
                             # trigger: [event_name]
      }.freeze

      CONDITIONS = ::Set.new(%i[on changed when skip trigger]).freeze

      include DelayedEvent
      include Options
      include Callbacks

      attr_reader :set_module, :opts

      def initialize event, stage_or_opts, opts, set_module, &final
        @event = event
        @set_module = set_module
        @opts = event_opts stage_or_opts, opts
        @event_block = final
      end

      def register
        validate_conditions
        Card.define_callbacks @event
        define_event
        set_event_callbacks
      end

      # @return the name of the event
      def name
        @event
      end

      def block
        @event_block
      end

      # the name for the method that only executes the code
      # defined in the event
      def simple_method_name
        "#{@event}_without_callbacks"
      end

      # the name for the method that adds the event to
      # the delayed job queue
      def delaying_method_name
        "#{@event}_with_delay"
      end

      private

      # EVENT DEFINITION

      def define_event
        define_simple_method
        define_event_method
      end

      def define_simple_method
        @set_module.class_exec(self) do |event|
          define_method event.simple_method_name, &event.block
        end
      end

      def define_event_method
        send "define_#{event_type}_event_method"
      end

      def event_type
        with_delay?(@opts) ? :delayed : :standard
      end

      def define_standard_event_method method_name=simple_method_name
        @set_module.class_exec(@event) do |event_name|
          define_method event_name do
            log_event_call event_name
            run_callbacks event_name do
              send method_name
            end
          end
        end
      end
    end
  end

  def log_event_call event
    Rails.logger.debug "#{name}: #{event}"
    # puts "#{name}: #{event}"
    # puts "#{Card::ActManager.to_s}".green
  end
end
