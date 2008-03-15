require 'poll/poll'

class Tool::RateMany < Page

  controller 'rate_many'
  model Poll::Poll
  icon 'rate-many.png'
  class_display_name 'approval vote'
  class_description "Approve or disapprove of each possibility."
    
  def initialize(*args)
    super(*args)
    self.data = Poll::Poll.new
  end
  
end
