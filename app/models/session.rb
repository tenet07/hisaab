class Session < ApplicationRecord
  belongs_to :user

  # "Chrome on Android", "Safari on iPhone" — recorded on every entry made from this session.
  def self.label_for(user_agent)
    ua = user_agent.to_s
    os = case ua
         when /iPhone/ then "iPhone"
         when /iPad/ then "iPad"
         when /Android/ then "Android"
         when /Windows/ then "Windows"
         when /Mac OS X/ then "Mac"
         when /Linux/ then "Linux"
         else "device"
         end
    browser = case ua
              when /Edg\// then "Edge"
              when /Chrome\// then "Chrome"
              when /Firefox\// then "Firefox"
              when /Safari\// then "Safari"
              else "browser"
              end
    "#{browser} on #{os}"
  end
end
