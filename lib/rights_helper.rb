module RightsHelper
  def submit_by_rights(value = "Save changes", options = {})
    html_options = options.with_indifferent_access

    message = html_options.delete(:deny)
    unless authorized_by(html_options.delete(:can?))
      html_options.delete(:confirm)
      html_options[:onclick] = [html_options[:onclick], access_denied(message)].compact.join(';')
    end

    submit_tag value, html_options
  end

  def link_by_rights *args, &block
    if block_given?
      options, html_options = args.first || {}, (args.second || {}).with_indifferent_access
      concat link_by_rights(capture(authorized_by(html_options[:can?]), &block), options, html_options)
    else
      name         = args.first
      options      = args.second || {}
      html_options = (args.third || {}).with_indifferent_access

      message = html_options.delete(:deny)
      unless authorized_by(html_options.delete(:can?))
        html_options.delete(:method)
        html_options.delete(:confirm)
        html_options[:onclick] = [html_options[:onclick], access_denied(message)].compact.join(';')
        html_options[:href] = 'javascript:void(0)'
      end
      link_to name, options, html_options
    end
  end

  def access_denied message = nil
    "alert('#{escape_javascript(message||'Access Denied')}');return false;"
  end
end