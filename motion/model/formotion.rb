module MotionModel
  module Formotion
    def self.included(base)
      base.extend(PublicClassMethods)
    end
    module PublicClassMethods
      def has_formotion_sections(sections = {})
        define_method( "formotion_sections") do
          sections
        end
      end
    end
    FORMOTION_MAP = {
      :string   => :string,
      :date     => :date,
      :time     => :date,
      :int      => :number,
      :integer  => :number,
      :float    => :number,
      :double   => :number,
      :bool     => :check,
      :boolean  => :check,
      :text     => :text
    }

    def should_return(column) #nodoc
      skippable = [:id]
      skippable += [:created_at, :updated_at] unless @expose_auto_date_fields
      !skippable.include?(column) && !relation_column?(column)
    end

    def returnable_columns #nodoc
      columns.select{|column| should_return(column)}
    end

    def default_hash_for(column, value)
      {:key         => column.to_sym,
       :title       => column.to_s.humanize,
       :type        => FORMOTION_MAP[column_type(column)],
       :placeholder => column.to_s.humanize,
       :value       => value
       }
    end

    def is_date_time?(column)
      column_type = column_type(column)
      [:date, :time].include?(column_type)
     end

    def value_for(column) #nodoc
      value = self.send(column)
      value = value.to_f if value && is_date_time?(column)
      value
    end

    def combine_options(column, hash) #nodoc
      options = column(column).options[:formotion]
      options ? hash.merge(options) : hash
    end

    # <tt>to_formotion</tt> maps a MotionModel into a hash suitable for creating
    # a Formotion form. By default, the auto date fields, <tt>created_at</tt>
    # and <tt>updated_at</tt> are suppressed. If you want these shown in
    # your Formotion form, set <tt>expose_auto_date_fields</tt> to <tt>true</tt>
    #
    # If you want a title for your Formotion form, set the <tt>form_title</tt>
    # argument to a string that will become that title.
    def to_formotion(form_title = nil, expose_auto_date_fields = false, first_section_title = nil)
      @expose_auto_date_fields = expose_auto_date_fields

      sections = {
        default: {rows: []}
      }
      if respond_to? 'formotion_sections'
        formotion_sections.each do |k,v|
          sections[k] = v
          sections[k][:rows] = []
        end
      end
      sections[:default][:title] ||= first_section_title

      returnable_columns.each do |column|
        value = value_for(column)
        h = default_hash_for(column, value)
        s = column(column).options[:formotion] ? column(column).options[:formotion][:section] : nil
        if s
          sections[s] ||= {}
          sections[s][:rows].push(combine_options(column,h))
        else
          sections[:default][:rows].push(combine_options(column, h))
        end
      end

      form = {
        sections: []
      }
      form[:title] ||= form_title
      sections.each do |k,section|
        form[:sections] << section
      end
      form
    end

    # <tt>from_formotion</tt> takes the information rendered from a Formotion
    # form and stuffs it back into a MotionModel. This data is not saved until
    # you say so, offering you the opportunity to validate your form data.
    def from_formotion!(data)
      self.returnable_columns.each{|column|
        if data[column] && column_type(column) == :date || column_type(column) == :time
          data[column] = Time.at(data[column]) unless data[column].nil?
        end
        value = self.send("#{column}=", data[column])
      }
    end
  end
end
