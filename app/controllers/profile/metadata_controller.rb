class Profile::MetadataController < ApplicationController
  before_filter :login_required
  before_filter :fetch_profile

  def item_partial
    controller_name.singularize.to_sym
  end

  def new
    @item = current_object_class.new
    if request.xhr?
      #render :head => :unprocessable_entity
      render :partial => "profiles/form/#{item_partial}", :locals => { item_partial => @item, :profile => @profile  }
    end
  end

  def current_object_class
    ('profile_'+(controller_name.demodulize)).classify.constantize
  end

  def destroy
    #@item = ::Profile.const_get(controller_name.demodulize.classify).find params[:id]
    @item = current_object_class.find params[:id]
    @item.destroy   
    
    
    respond_to do |format|
      format.html do
        flash[:notice] = "#{@item} deleted"
        redirect_to edit_person_profile_path(@profile.entity)
      end 
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  protected
  
  def fetch_profile
    @profile = Profile.find( params[:profile_id]) rescue current_user.private_profile
    @profile && current_user.may!( :admin, @profile )
  end
end
