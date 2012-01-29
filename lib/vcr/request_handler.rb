module VCR
  # @private
  class RequestHandler
    def handle
      invoke_before_request_hook

      # The before_request hook can change the type of request
      # (i.e. by inserting a cassette), so we need to query the
      # request type again.
      #
      # Likewise, the main handler logic an modify what
      # #request_type would return (i.e. when a response stub is
      # used), so we need to store the request type for the
      # the after_request hook.
      set_typed_request_for_after_hook

      send "on_#{request_type}_request"
    end

  private

    def typed_request
      Request::Typed.new(vcr_request, request_type)
    end

    def set_typed_request_for_after_hook
      @after_hook_typed_request = typed_request
    end

    def request_type
      case
        when should_ignore?                     then :ignored
        when has_response_stub?                 then :stubbed
        when VCR.real_http_connections_allowed? then :recordable
        else                                         :unhandled
      end
    end

    def invoke_before_request_hook
      return if disabled?
      VCR.configuration.invoke_hook(:before_http_request, typed_request)
    end

    def invoke_after_request_hook(vcr_response)
      return if disabled?
      VCR.configuration.invoke_hook(:after_http_request, @after_hook_typed_request, vcr_response)
    end

    def should_ignore?
      disabled? || VCR.request_ignorer.ignore?(vcr_request)
    end

    def disabled?
      VCR.library_hooks.disabled?(library_name)
    end

    def has_response_stub?
      VCR.http_interactions.has_interaction_matching?(vcr_request)
    end

    def stubbed_response
      @stubbed_response ||= VCR.http_interactions.response_for(vcr_request)
    end

    def library_name
      # extracts `:typhoeus` from `VCR::LibraryHooks::Typhoeus::RequestHandler`
      @library_name ||= self.class.name.split('::')[-2].downcase.to_sym
    end

    # Subclasses can implement these
    def on_ignored_request
    end

    def on_stubbed_request
    end

    def on_recordable_request
    end

    def on_unhandled_request
      raise VCR::Errors::UnhandledHTTPRequestError.new(vcr_request)
    end
  end
end
