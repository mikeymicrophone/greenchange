DemocracyInAction::API.__send__ :class_variable_set, :@@DEFAULT_URLS, { 'get' => 'http://salsa.wiredforchange.com/dia/api/get.jsp', 'process' => 'http://salsa.wiredforchange.com/dia/api/process.jsp', 'delete' => 'http://salsa.wiredforchange.com/delete' }

require 'net/https'
class DemocracyInAction::API
  def login
    puts "logging in" if $DEBUG
    url = URI.parse('https://salsa.wiredforchange.com/dia/hq/processLogin.jsp')
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    res = http.post(url.path, "email=#{user}&password=#{password}")
    cookies = res['set-cookie']

    if cookies
      @cookies = []
      cookies.each { |c| @cookies.push(c.split(';')[0]) }
    end
  end

  def process_with_login(*args)
    return '' if DemocracyInAction::API.disabled?
    login if args.last.is_a?(Hash) && args.last.keys.include?('key')
    key = process_without_login(*args)
    if "0" == key
      login
      key = process_without_login(*args)
    end
    key
  end
  alias_method_chain :process, :login

  def delete(table, criteria)
    options = processOptions(table, criteria)
    options['object'] = options.delete('table')
    options.delete('simple')
    options['xml'] = true

    res = sendRequest(@urls['delete'], criteria)
    # if it contains '<success', it worked, otherwise a failure
    if res.include?('<success')
      return true
    else
      puts res if $DEBUG
      return false
    end
  end

  def delete_with_login(*args)
    return false if DemocracyInAction::API.disabled?
    unless (success = delete_without_login(*args))
      login
      success = delete_without_login(*args)
    end
    return success
  end
  alias_method_chain :delete, :login
end

DemocracyInAction.configure do
  begin
    config = YAML.load_file(File.join('config', 'democracy_in_action.yml'))

    auth.username = config[:auth][:username]
    auth.password = config[:auth][:password]
    auth.org_key =  config[:auth][:org_key]
  rescue Errno::ENOENT
    RAILS_DEFAULT_LOGGER.warn 'no democracy in action config'
  end

  #NOTE: mirror means save to DIA every time this object is saved, 
  #      AND delete from DIA when destroyed
  #
  #another NOTE:
  #      turns out it's better to just do this mapping from profile
#  mirror(:supporter, User) do
#    map('First_Name')     { |user| user.private_profile.first_name if user.private_profile }
#    map('Last_Name')      { |user| user.private_profile.last_name if user.private_profile }
#    map('Organization')   { |user| user.private_profile.organization if user.private_profile }
#  end

  mirror(:supporter, Profile) do
    guard { |profile| profile.entity.is_a?(User) }

    map('Email')          { |profile|
      user = profile.user
      user.email if user
    }
    map('First_Name')     { |profile| profile.first_name if profile.private? }
    map('Last_Name')      { |profile| profile.last_name if profile.private? }
    map('Organization')   { |profile| profile.organization if profile.private? }
    map('Source_Details', 'network')
  end

  #maybe don't need mirror here.  more like an after_create.
  mirror(:groups, Group) do
    map('parent_KEY', 35540)
    map('Group_Name') { |group| group.name }
  end

  mirror(:supporter_groups, Membership) do
    map('supporter_KEY') { |membership| 
      user = membership.user
      if user
        profile = user.private_profile
        if profile
          proxy = profile.democracy_in_action_proxies.find_by_remote_table('supporter')
          proxy.remote_key if proxy
        end
      end
    }
    map('groups_KEY') { |membership| 
      group = membership.group
      if group
        proxy = group.democracy_in_action_proxies.find_by_remote_table('groups')
        proxy.remote_key if proxy
      end
    }
  end

  mirror(:supporter_groups, Preference ) do
    guard { |pref| pref.value == "1" and pref.name =~ /subscribe_to_email_list|allow_info_sharing/ and pref.user_id }
    map('supporter_KEY') { |preference|
      user = preference.user
      if user
        profile = user.private_profile 
        if profile
          proxy = profile.democracy_in_action_proxies.find_by_remote_table('supporter')
          proxy.remote_key if proxy
        end
      end
    }
    map('groups_KEY') { |preference|
      case preference.name
        when 'subscribe_to_email_list'
          Crabgrass::Config.dia_subscribe_to_email_list_group_id
        when 'allow_info_sharing'
          Crabgrass::Config.dia_allow_info_sharing_group_id
      end
    } 
  end

#  mirror.event               = Event
#  c.mirror.supporter_event     = Attentance

=begin
  # if we had multiple tables per model
  mirror(:groups, User) do
    map('groups_KEY') { |user| user.democracy_in_action_list }
  end
=end
end
