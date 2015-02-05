
include Type::SearchType
def item_cards params={}
  start = params[:offset] || 0
  stop = params[:limit] ? start + params[:limit] : -1
  Card.members(key)[start..stop].map {|item| Card.fetch(item) }.compact
end

def item_names params={}
  item_cards.map{ |item_card| item_card.cardname }
end

def count params={}
  Card.members(key).size
end

def query params={}
  {}
end

format do
  include Type::SearchType::Format
end

format :html do
  include Type::SearchType::HtmlFormat
    
  view :members do |args|
   frame args.merge(:title=>card.follow_label) do
      subformat(card)._render_card_list args
    end
  end

  view :core do |args|
    body = card.setting_codenames_by_group.map do |group, data|
      next if group.nil? || data.nil?
      group_name = Card::Setting.group_names[group] || group.to_s
      content_tag(:tr, :class=>"rule-group") do
        (["#{group_name} Rules"]+%w{Content Set}).map do |heading|
          content_tag(:th, :class=>'rule-heading') { heading }
        end * "\n"
      end +
      raw( data.map do |setting|
        rule_card = card.fetch(:trait=>setting, :new=>{})
        nest rule_card, :view=>:closed_rule
      end * "\n" )
    end.compact * ''
    %{
      #{
        unless args[:unlabeled]
          %{ <h2 class="set-label">#{ card.label }</h2> }
        end
      }
      #{ content_tag('table', :class=>'set-rules') { body } }
    }
  end


  view :editor do |args|
    'Cannot currently edit Sets' #ENGLISH
  end
  
  view :template_link do |args|
    args.delete :style
    wrap args do
      link = view_link args[:inc_syntax], :template_editor, :class=>'slotter' #, 'slot-include'=>include_syntax
      "{{#{link}}}"
    end
  end
  
  view :template_closer do |args|
    view_link '', :template_link, :class=>'slotter ui-icon ui-icon-closethick template-editor-close'
  end
  
  view :template_editor do |args|
    wrap args do
      %{
        <div class="template-editor-left">{{</div> 
        <div class="template-editor-main">
          #{
            frame :no_slot=>true, :title=>card.label, :menu_hack=>:template_closer do
              _render_core args.merge(:unlabeled=>true)
            end
          }
        </div>
        <div class="template-editor-right">}}</div> 
      }
    end
  end
  
  view :closed_content do |args|
    ''
  end

  view :follow_link_name do |args|
    args[:toggle] ||= card.followed? ? :off : :on
    if args[:toggle] == :off
      'following'
    elsif card.right and card.right.codename == 'self'
      'follow'
    else
      'follow all'
    end
  end
  
end


include Card::Set::Type::SearchType

def default_follow_set_card
  self
end

def inheritable?
  return true if junction_only?
  cardname.trunk_name.junction? and cardname.tag_name.key == Card::SelfSet.pattern.key
end

def subclass_for_set
  set_class_key = tag.codename
  Card.set_patterns.find do |sub|
    cardname.tag_name.key == sub.pattern.key
  end
end

def junction_only?()
  if @junction_only.nil?
    @junction_only = subclass_for_set.junction_only
  else
    @junction_only
  end
end

def reset_set_patterns
  Card.members( key ).each do |mem|
    Card.expire mem
  end
end

def label
  if klass = subclass_for_set
    klass.label cardname.left
  else
    ''
  end
end

def follow_label
  if klass = subclass_for_set
    klass.follow_label cardname.left
  else
    ''
  end
end

def follow_rule_name user=nil
  if user
    if user.kind_of? String
      "#{name}+#{Card[:follow].name}+#{user}"
    else
      "#{name}+#{Card[:follow].name}+#{user.name}"
    end
  else
    "#{name}+#{Card[:follow].name}+#{Card[:all].name}"
  end
end

def to_following_item_name args
  left_part = follow_rule_name( args[:user] )
  option = args[:option] || if (rule_card = Card.fetch(left_part))
       rule_card.content
     else
       Card[:nothing].name
     end
  
  "#{left_part}+#{option}"
end

def all_user_ids_with_rule_for setting_code
  Card.all_user_ids_with_rule_for self, setting_code
end


def setting_codenames_by_group
  result = {}
  Card::Setting.groups.each do |group, settings| 
    visible_settings = settings.reject { |s| !s or !s.applies_to_cardtype(prototype.type_id) }
    unless visible_settings.empty?
      result[group] = visible_settings.map { |s| s.codename }
    end
  end
  result
end

def prototype
  opts = subclass_for_set.prototype_args self.cardname.trunk_name
  Card.fetch opts[:name], :new=>opts
end
