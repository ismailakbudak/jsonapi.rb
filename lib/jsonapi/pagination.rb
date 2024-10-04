module JSONAPI
  # Pagination support
  module Pagination
    private
    # Default number of items per page.
    JSONAPI_PAGE_SIZE = ENV.fetch('PAGINATION_LIMIT') { 30 }
    # Default number of items per page.
    PAGINATION_IGNORE_KEYS = %i[total_count total_page]

    # Applies pagination to a set of resources
    #
    # Ex.: `GET /resource?page[number]=2&page[size]=10`
    #
    # @return [ActiveRecord::Base] a collection of resources
    def jsonapi_paginate(resources, options = {})
      offset, limit, _ = jsonapi_pagination_params

      if resources.respond_to?(:offset)
        resources = resources.offset(offset).limit(limit)
      else
        original_size = resources.size
        resources = resources[(offset)..(offset + limit - 1)] || []

        # Cache the original resources size to be used for pagination meta
        resources.instance_variable_set(:@original_size, original_size)
      end

      if options[:total_count]
        resources.instance_variable_set(
          :@_predefined_total_count,
          options[:total_count]
        )
      end

      block_given? ? yield(resources) : resources
    end

    # Generates the pagination links
    #
    # @return [Array]
    def jsonapi_pagination(resources)
      links = {}

      pagination = jsonapi_pagination_builder(resources)

      return links if pagination.blank?

      original_params = params.except(
        *jsonapi_path_parameters.keys.map(&:to_s)
      ).as_json.with_indifferent_access

      original_params[:page] = original_params[:page].dup || {}
      original_url = '?'

      pagination.each do |page_name, number|
        next if PAGINATION_IGNORE_KEYS.include?(page_name)

        original_params[:page][:number] = number
        arg_params = original_params
        if page_name == :first || (number && number == 1)
          arg_params = original_params.except(:page)
        end

        links[page_name] = number.nil? ? nil : (
          original_url + CGI.unescape(arg_params.to_query)
        )
      end

      links
    end

    # Generates pagination numbers
    #
    # @return [Hash] with the first, previous, next, current, last page,
    # total_count, total_page numbers
    def jsonapi_pagination_builder(resources)
      return @_numbers if @_numbers
      return {} unless JSONAPI::Rails.is_collection?(resources)

      _, limit, page = jsonapi_pagination_params

      numbers = {
        current: page,
        first: nil,
        prev: nil,
        next: nil,
        last: nil
      }

      total = resources.instance_variable_get(:@_predefined_total_count)
      if total
        # do nothing for this condition
      elsif resources.respond_to?(:unscope)
        total = resources.unscope(:limit, :offset, :order).size
      else
        # Try to fetch the cached size first
        total = resources.instance_variable_get(:@original_size)
        total ||= resources.size
      end

      last_page = [1, (total.to_f / limit).ceil].max

      numbers[:first] = 1
      numbers[:last] = last_page

      if page > 1
        numbers[:prev] = page - 1
      end

      if page < last_page
        numbers[:next] = page + 1
      end

      if total.present?
        numbers[:total_count] = total
        numbers[:total_page] = last_page
      end

      @_numbers = numbers
    end

    # Extracts the pagination meta
    #
    # @return [Hash] with the first, previous, next, current, last page numbers
    def jsonapi_pagination_meta(resources)
      pagination = jsonapi_pagination_builder(resources)
      pagination.slice(:total_count, :total_page, :current)
    end

    # Extracts the pagination params
    #
    # @return [Array] with the offset, limit and the current page number
    def jsonapi_pagination_params
      pagination = params[:page].try(:slice, :number, :size) || {}
      per_page = jsonapi_page_size(pagination)
      num = [1, pagination[:number].to_f.to_i].max

      [(num - 1) * per_page, per_page, num]
    end

    # Retrieves the default page size
    #
    # @param per_page_param [Hash] opts the paginations params
    # @option opts [String] :number the page number requested
    # @option opts [String] :size the page size requested
    #
    # @return [Integer]
    def jsonapi_page_size(pagination_params)
      per_page = pagination_params[:size].to_f.to_i

      return self.class
              .const_get(:JSONAPI_PAGE_SIZE)
              .to_i if per_page < 1

      per_page
    end

    # Fallback to Rack's parsed query string when Rails is not available
    #
    # @return [Hash]
    def jsonapi_path_parameters
      return request.path_parameters if request.respond_to?(:path_parameters)

      request.send(:parse_query, request.query_string, '&;')
    end
  end
end
