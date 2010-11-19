module Cardlib
  module Cacheable
    
    def template?
      name && name.template_name?
    end
       
    def type_template?
      name && name =~ /\+\*type\+/
    end

    def right_template?
      name && name =~ /\+\*right\+/
    end
       
    def hard_template?(format=:html)
      name && (name =~ /\+\*content$/ || format==:xml && name =~ /\+\*xml content$/)
    end

    def soft_template?
      name && name =~ /\*default/
    end

    def pointees( context = nil )
      User.as(:wagbot) do
        links = content.split(/\n+/).map{ |x| x.gsub(/\[\[|\]\]/,'')}.map{|x|
          context ? x.to_absolute(context) : x
        }
      end
    end
    
    def pointee
      pointees.first
    end    
    
    # FIXME: maybe this should be methods in individual classes?
    def list_items context = nil
      case self.type
      when "Pointer"
        self.pointees( context ? context.name : nil )
      when "Search"
        self.list_cards(context).map {|card| card.name }
      when "File","NimbbVideo"
        [self.name]
      else
        self.content.split(/[,\n]/)
      end
    end
    
    def list_cards context = nil
      case self.type
      when "Pointer";
        self.list_items( context ).map{|cardname| Card.fetch( cardname, :skip_virtual=>true ) }.compact
      when "Search";
        self.search(:limit => "", :_self=>(context ? context.name : self.name))
      else
        [self]
      end
    end
    
    def extended_list context = nil
      # this could go on and on..
      self.list_cards(context).map{|x| x.list_cards(context) }.flatten.map{|x| x.list_items(context) }.flatten
    end
    
    def contextual_content context = nil, format=:html
      context ||= self
      renderer = Renderer.new
      prerender = renderer.render( self, self.templated_content(format),
                                   self.references_expired, [:raw, format])
      renderer.render( context, prerender, context.references_expired, format )
    end

    def cardtype_name
      Cardtype.name_for( self.type )
    end

    def left
      Card.fetch( name.trunk_name , :skip_virtual => true)
    end
    
    # FIXME: limit moved here from pointer card.
    # This fixes explosion creating pointer cards, but it
    # should be refactored.    
    def limit
      card = System.setting("#{self.name.tag_name}+*max") or return nil
      card.content.strip.to_i
    end    
    
  end
end
