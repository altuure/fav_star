module FavStar
	module ActsAsFaveable #:nodoc:

		def self.included(base)
			base.extend ClassMethods
		end

		module ClassMethods
			def acts_as_faveable
				has_many :faves, :as => :faveable, :dependent => :destroy

				include FavStar::ActsAsFaveable::InstanceMethods
				extend  FavStar::ActsAsFaveable::SingletonMethods
				if (options[:fave_counter])

					Vote.send(:include,  FavStar::ActsAsFaveable::FaveCounterClassMethods)   unless Fave.respond_to?(:vote_counters)
					Vote.vote_counters << self


					counter_column_name = (options[:vote_counter] == true) ? :vote_counter : options[:vote_counter]

					class_eval <<-EOS
					def self.vote_counter_column           # def self.vote_counter_column
						:"#{counter_column_name}"            #   :vote_total
					end                                    # end
					def vote_counter_column
						self.class.vote_counter_column
					end
					EOS

					define_method(:reload_vote_counter) {reload(:select => vote_counter_column.to_s)}
					attr_readonly counter_column_name
				end
			end
		end

		module SingletonMethods

			def faved_by(faver)
				self.joins(:faves).where(
				:faves => {
					:faver_type => faver.class.name,
					:faver_id => faver.id
				}
				)
			end

		end

		module InstanceMethods

			def faves
				Fave.where(:faveable_id => id, :faveable_type => self.class.name).count
			end

			def favers
				self.faves.map(&:faver).uniq
			end

			# DEPRECIATED:
			def favers_who_faved
				puts "The method 'favers_who_faved' has been depreciated in favour of just 'favers'."
				favers
			end

			def faved_by?(faver)
				0 < Fave.where(
				:faveable_id => self.id,
				:faveable_type => self.class.name,
				:faver_type => faver.class.name,
				:faver_id => faver.id
				).count
			end

		end

		module FaveCounterClassMethods
			def self.included(base)
				base.class_attribute(:vote_sum_counters)
				base.vote_sum_counters=Array.new
				base.before_save { |record| record.update_vote_sum_counters(nil) }
				base.before_destroy { |record| record.update_vote_sum_counters(-1) }
			end

			def update_vote_sum_counters direction
				klass, vtbl = self.voteable.class, self.voteable

				v=0
				v_was=0
				if self.vote_changed? || (self.new_record? && self.vote==false )
					v=(self.vote==true) ? 1 :-1;
				end
				if direction!=nil
					v_was=(self.vote_was==true) ? -1 :1
				end
				v=v+v_was

				if v!=0
					klass.update_counters(vtbl.id, vtbl.vote_sum_counter_column.to_sym => (v ) ) if self.vote_sum_counters.any?{|c| c == klass}
				end
			end
		end
	end
end