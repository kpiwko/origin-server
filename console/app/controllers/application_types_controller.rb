class ApplicationTypesController < ConsoleController

  include Console::ModelHelper

  def index
    @capabilities = user_capabilities
    flash.now[:warning] = "You have no free gears.  You'll need to scale down or delete another application first." unless @capabilities.gears_free?

    @browse_tags = [
      ['Java', :java],
      ['PHP', :php],
      ['Ruby', :ruby],
      ['Python', :python],
      ['Node.js', :nodejs],
      ['Perl', :perl],
      nil,
      ['All web cartridges', :cartridge],
      ['All instant applications', :instant_app],
      nil,
      ['Blogs', :blog],
      ['Content management systems', :cms],
      #['MongoDB', :mongo],
    ]

    if @tag = params[:tag].presence
      types = ApplicationType.tagged(@tag)
      @type_groups = [["Tagged with #{Array(@tag).to_sentence}", types.sort!]]

      render :search
    elsif @search = params[:search].presence
      types = ApplicationType.search(@search)
      @type_groups = [["Matches search '#{@search}'", types]]

      render :search
    else
      types = ApplicationType.all
      @featured_types = types.select{ |t| t.tags.include?(:featured) }.sample(3).sort!
      groups, other = in_groups_by_tag(types - @featured_types, [:instant_app, :java, :php, :ruby, :python])
      groups.each do |g|
        g[2] = application_types_path(:tag => g[0])
        g[1].sort!
        g[0] = I18n.t(g[0], :scope => :types, :default => g[0].to_s.titleize)
      end
      groups << ['Other types', other.sort!] unless other.empty?
      @type_groups = groups
    end
  end

  def show
    app_params = params[:application] || params
    app_type_params = params[:application_type] || app_params
    @advanced = to_boolean(params[:advanced])

    user_default_domain rescue (@domain = Domain.new)

    @compact = false # @domain.persisted?

    @application_type = params[:id] == 'custom' ?
      ApplicationType.custom(app_type_params) :
      ApplicationType.find(params[:id])

    @capabilities = user_capabilities :refresh => true

    @application = (@application_type >> Application.new(:as => current_user)).assign_attributes(app_params)
    @application.gear_profile = @capabilities.gear_sizes.first unless @capabilities.gear_sizes.include?(@application.gear_profile)
    @application.domain_name = app_params[:domain_name].presence || app_params[:domain_id].presence

    begin
      @cartridges, @missing_cartridges = @application_type.matching_cartridges
      flash.now[:error] = "No cartridges are defined for this type - all applications require at least one web cartridge" unless @cartridges.present?
    rescue ApplicationType::CartridgeSpecInvalid
      logger.debug $!
      flash.now[:error] = "The cartridges defined for this type are not valid.  The #{@application_type.source} may not be correct."
    end

    flash.now[:error] = "You have no free gears.  You'll need to scale down or delete another application first." unless @capabilities.gears_free?
    @disabled = @missing_cartridges.present? || @cartridges.blank?

    user_default_domain rescue nil
  end
end
