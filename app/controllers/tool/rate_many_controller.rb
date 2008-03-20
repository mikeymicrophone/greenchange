class Tool::RateManyController < Tool::BaseController
  before_filter :fetch_poll
    
  def show
  	@possibles = @poll.possibles.sort_by{|p| p.position||0 }
  end
  
  # ajax or post
  def add_possible
    return if request.get?
    @possible = @poll.possibles.create params[:possible]
    if @poll.valid? and @possible.valid?
      @page.unresolve
      redirect_to survey_url(@page) unless request.xhr?
    else
      @poll.possibles.delete(@possible)
      message :object => @possible unless @possible.valid?
      message :object => @poll unless @poll.valid?
      if request.post? 
        render :action => 'show'
      else
        render :text => 'error', :status => 500
      end
      return
    end
  end
      
  def destroy_possible
    return unless @poll
    possible = @poll.possibles.find(params[:possible_id])
    possible.destroy
    redirect_to survey_url(@page)
  end
  
  def vote_one
    new_value = params[:value].to_i
    @possible = @poll.possibles.find(params[:id])
    @poll.delete_votes_by_user_and_possible(current_user,@possible)
    @possible.votes.create :user => current_user, :value => new_value
    current_user.updated(@page, :resolved => true)
  end
  
  def vote
    new_votes = params[:vote] || {} 

    # destroy previous votes
    @poll.votes_by_user(current_user).each{|v| v.destroy}

    # create new votes
    @poll.possibles.each do |possible|
      weight = new_votes[possible.id.to_s]
      possible.votes.create :user => current_user, :value => weight if weight
    end
    current_user.updated(@page, :resolved => true)
    redirect_to survey_url(@page)
  end

  def clear_votes
    @poll.votes.clear
    redirect_to survey_url(@page)
  end
    
  # ajax only, returns nothing
  # for this to work, there must be a <ul id='sort_list_xxx'> element
  # and it must be declared sortable like this:
  # <%= sortable_element 'sort_list_xxx', .... %>
  def sort
    return unless params[:sort_list].any?
    ids = params[:sort_list]
    @poll.possibles.each do |possible|
      position = ids.index( possible.id.to_s )
      possible.update_attribute('position',position+1) if position
    end	
    render :nothing => true
  end
  
  protected
  
  # eventually, add more fine grained permissions.
  # this is the default:
#  def authorized?
#    if @page
#      current_user.may?(:admin, @page)
#    else
#      true
#    end
#  end

  def fetch_poll
    return true unless @page
    @poll = @page.data
  end

end
