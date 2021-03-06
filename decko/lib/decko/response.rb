module Decko
  # methods for managing decko responses
  module Response
    private
    def respond format, result, status
      if status == 302
        hard_redirect result
      elsif format.is_a?(Card::Format::FileFormat) && status == 200
        send_file(*result)
      else
        render_response result.to_s.html_safe, status, format.mime_type
      end
    end

    def render_response body, status, content_type
      render body: body, status: status, content_type: content_type
    end

    # return a redirect response
    def hard_redirect url
      url = card_url url # make sure we have absolute url
      if Card::Env.ajax?
        # lets client reset window location
        # (not just receive redirected response)
        # formerly used 303 response, but that gave IE the fits
        render json: { redirect: url }
      else
        redirect_to url
      end
    end

    # return a standard GET response directly.
    # Used in AJAX situations where PRG pattern is unwieldy
    def soft_redirect success
      @card = success.target
      require_card_for_soft_redirect!
      self.params = Card::Env[:params] = soft_redirect_params
      load_action
      show
    end

    def soft_redirect_params
      new_params = params.clone
      new_params.delete :card
      new_params.delete :action
      new_params.merge Card::Env.success.params
    end

    def require_card_for_soft_redirect!
      return if card.is_a? Card
      raise Card::Error, "tried to do soft redirect without a card"
    end

    # (obviously) deprecated
    def send_deprecated_asset
      filename = [params[:mark], params[:format]].join(".")
      # for security, block relative paths
      raise Card::Error::BadAddress if filename.include? "../"
      path = Decko::Engine.paths["gem-assets"].existent.first
      send_file File.join(path, filename), x_sendfile: true
    end

    # TODO: everything below should go in a separate file
    # below is about beginning (initialization).  above is about end (response)
    # Both this file and that would make sense as submodules of CardController

    def load_format
      request.format = :html if Card::Env.ajax? && !params[:format]
      card.format format_name_from_params
    end

    def format_name_from_params
      explicit_file_format? ? :file : request.format.to_sym
    end

    def explicit_file_format?
      params[:explicit_file] || !Card::Format.registered.member?(request.format)
    end

    def interpret_mark mark
      case mark
      when "*previous"
        # Why support this? It's only needed in Success, right? Deprecate?
        return hard_redirect(Card::Env.previous_location)
      when nil
        implicit_mark
      else
        explicit_mark mark
      end
    end

    def explicit_mark mark
      # we should find the place where we produce these bad urls
      mark.valid_encoding? ? mark : mark.force_encoding("ISO-8859-1").encode("UTF-8")
    end

    def implicit_mark
      case
      when initial_setup                    then ""
      when (name = params.dig :card, :name) then name
      when view_does_not_require_name?      then ""
      else                                       home_mark
      end
    end

    def home_mark
      Card.global_setting(:home) || "Home"
    end

    def view_does_not_require_name?
      Card::Format.tagged params[:view], :unknown_ok
    end

    # alters params
    def initial_setup
      return unless initial_setup?
      prepare_setup_card!
    end

    def initial_setup?
      Card::Auth.needs_setup? && Card::Env.html?
    end

    def prepare_setup_card!
      params[:card] = { type_id: Card.default_accounted_type_id }
      params[:view] = "setup"
    end
  end
end
