require_relative '../lib/mongoid_fixtures/version'
require 'yaml'
require 'singleton'
require 'linguistics'

module MongoidFixtures

  class Loader
    include Singleton

    attr_accessor :fixtures, :path

    def initialize
      @fixtures = {}
    end

    def self.load
      fix = MongoidFixtures::Loader.instance
      fixture_names = Dir[File.join(File.dirname(__FILE__), "../#{path}/*.yml")]

      fixture_names.each do |fixture|
        fix.fixtures[File.basename(fixture, '.*')] = YAML.load_file(fixture)
      end
      fix
    end

    def self.path=(var)
      Loader.instance.path = var
    end

    def self.path
      Loader.instance.path
    end
  end

  Linguistics.use( :en )
  Loader::path = 'test/fixtures'
  Loader::load

  def self.load(clazz)
    fixture_instances = Loader.instance.fixtures[clazz.to_s.downcase.en.plural] # get class name
    instances = {}
    fixture_instances.each do |key, fixture_instance|
      instance = clazz.new
      fields = fixture_instance.keys
      fields.each do |field|

        value = fixture_instance[field]
        field_label = field.to_s.capitalize
        field_clazz = resolve_class_ignore_plurality(field_label)

        # If the current value is a symbol then it respresents another fixture.
        # Find it and store its id
        if value.is_a? Symbol
          instance[field] = field_clazz.load(Loader.instance.fixtures([field.en.plural]))[value].id
        # If the current value is an array find each fixture_instance and get its document to serialize
        # This approach (should) assume nested documents. This will be addressed in later versions
        elsif value.is_a? Array
          values = []
          value.each do |v|
            if field_clazz.nil?
              values << v
            else
              values << field_clazz.load(Loader.instance.fixtures([field]))[v].as_document
            end
          end
          instance[field] = values
        # else just set the field
        else
          instance[field] = value
        end
      end
      instance.save! # auto serialize the document
      instances[key] = instance # store it based on its key name
    end
    instances
  end

  def self.resolve_class_ignore_plurality(class_name)
    if class_exists?(class_name) then
      Kernel.const_get(class_name)
    else
      if class_exists?(class_name[0, (class_name.size - 1)]) then
        Kernel.const_get(class_name[0, (class_name.size - 1)])
      else
        nil
      end
    end
  end
  
  def self.class_exists?(class_name)
    klass = Module.const_get(class_name)
    return klass.is_a?(Class)
  rescue NameError
    return false
  end

end
