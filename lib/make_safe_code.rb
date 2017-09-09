class SafeRuby
  class Sandbox
    class << self
      def run!(code)
        binding.eval(code)
      end

      def keep_singleton_methods(klass, singleton_methods)
        klass = Object.const_get(klass)
        singleton_methods = singleton_methods.map(&:to_sym)
        undef_methods = (klass.singleton_methods - singleton_methods)

        undef_methods.each do |method|
          klass.singleton_class.send(:undef_method, method) rescue next
        end

      end

      def keep_methods(klass, methods)
        klass = Object.const_get(klass)
        methods = methods.map(&:to_sym)
        undef_methods = (klass.methods(false) - methods)
        undef_methods.each do |method|
          klass.send(:undef_method, method) rescue next
        end  
      end

      def clean_constants
        WhiteList.skip_classes.each do |const|
          # Allow for active record base classes to be in here.
          next if const.is_a?(ActiveRecord::Base)

          puts "Undefining: #{const}"

          Object.send(:remove_const, const) if defined?(const)
        end
      end

    def init_sandbox

        Kernel.class_eval do
          def `(*args)
            raise NoMethodError, "` is unavailable"
          end

          def system(*args)
            raise NoMethodError, "system is unavailable"
          end
        end
        
        keep_singleton_methods(:Kernel, KERNEL_S_METHODS)
        keep_singleton_methods(:Symbol, SYMBOL_S_METHODS)
        keep_singleton_methods(:String, STRING_S_METHODS)
        keep_singleton_methods(:IO, IO_S_METHODS)

        keep_methods(:Kernel, KERNEL_METHODS)
        keep_methods(:NilClass, NILCLASS_METHODS)
        keep_methods(:TrueClass, TRUECLASS_METHODS)
        keep_methods(:FalseClass, FALSECLASS_METHODS)
        keep_methods(:Enumerable, ENUMERABLE_METHODS)
        keep_methods(:String, STRING_METHODS)
       

        clean_constants
      end
    end
  end
end