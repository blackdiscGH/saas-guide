class SubscriptionsController < ApplicationController

	before_action :authenticate_user!

	def new
		@plans = Plan.all
	end

	def edit
		@account = Account.find(params[:id])
		@plans = Plan.all	
	end 


	def index
		@account = Account.find_by_email(current_user.email)
		logger.debug { "----->ENTERED Subscriptions_controller#index<-----"}
		logger.debug { "@account #{@account}" }
		logger.debug { "@account.active_until #{@account.active_until}" }
		logger.debug { "current_user #{current_user}" }
		logger.debug { "current_user.email #{current_user.email}" }
		logger.debug { ".....>EXITED Subscriptions_controller#index<...."}

	end

	def update_card
	end

	def update_card_details
		# Take the token given and set it on Customer
		binding.pry 
		token 			= params[:stripeToken]
		current_account = Account.find_by_email(current_user.email)
		customer_id		= current_account.customer_id

		#Get the customer from Stripe
		customer = Stripe::Customer.retrieve(customer_id)

		#Set new card token
		customer.source = token
		customer.save

		redirect_to "/subscriptions", notice: "Card updated successfully"

	rescue => e
		redirect_to action: "update_card", flash: {error: e.message}
	end


	def create
		# Set your secret key: remember to change this to your live secret key in production
		# See your keys here https://dashboard.stripe.com/account/apikeys
		Stripe.api_key = "sk_test_52ACGAHGhXh8elFfA9GQ5xOf"

		logger.debug { "----->ENTERED Subscriptions_controller#create<-----"}
		

		# Get the credit card details submitted by the form
		token 			= params[:stripeToken]
		plan 			= params[:plan][:stripe_id]
		email 			= current_user.email
		current_account = Account.find_by_email(current_user.email)
		customer_id 	= current_account.customer_id
		current_plan 	= current_account.stripe_plan_id


		if customer_id.nil?
			#new customer
			# Create a Customer
			@customer = Stripe::Customer.create(
		  		:source => token,
		  		:plan => plan,
		  		:email => email
			)
		subscriptions = @customer.subscriptions
		@subscribed_plan = subscriptions.data.find {|o| o.plan.id == plan}

		else
			#Customer Exists
			#Get Customer object from Stripe
			@customer  		 =Stripe::Customer.retrieve(customer_id)
			#Get current subscription if any
			@subscribed_plan = create_or_update_subscriptions(@customer,current_plan, plan)
		end

		#get current period end date - This is a unix timestamp
		current_period_end = @subscribed_plan.current_period_end
		active_until = Time.at(current_period_end).to_datetime
		logger.debug { "current_period_end #{current_period_end}" }
		logger.debug { "active_until #{active_until}" }
		logger.debug { ".....>EXITED Subscriptions_controller#index<...."}


		# Customer create with a valid subscription
		save_account_details(current_account, plan, @customer.id, active_until)
		redirect_to :root, notice: "Successfully subsribed to a plan"

		rescue => e
			redirect_to :back, flash: {error: e.message}

	
	end

	def cancel_subscription
		binding.pry
		email 			= current_user.email
		current_account = Account.find_by_email(current_user.email)
		customer_id 	= current_account.customer_id
		current_plan 	= current_account.stripe_plan_id

		if current_plan.blank?
			raise "No plan found to be unsubscribed/cancelled"
		end


		#Fetch customer from stripe
		customer = Stripe::Customer.retrieve(customer_id)
		#Get current subscription from Stripe
		subscriptions = customer.subscriptions
		#Retrieve the subscription that you want to delete
		current_subscribed_plan = subscriptions.data.find {|o| o.plan.id == current_plan}
		if current_subscribed_plan.blank?
			raise "Subscription not found"
		end
		#Delete it
		current_subscribed_plan.delete 

		#Update the Account model
		save_account_details(current_account,"",customer_id, Time.at(0).to_datetime)
		@message = "Subscription cancelled successfully"
	
		rescue => e
			redirect_to "/subscriptions", flash: {error: e.message}
	end


	def save_account_details(account, plan, customer_id, active_until)
		# Update the Account model with details
		account.stripe_plan_id 	= plan
		account.active_until 	= active_until
		account.customer_id 	= customer_id
		account.save
	end


	def create_or_update_subscriptions(customer, current_plan, new_plan)
		subscriptions = customer.subscriptions 
		#Get current subscriptions
		current_subscription = subscriptions.data.find {|o| o.plan.id == current_plan}

		if current_subscription.blank?
			#no current subscription
			#maybe the customer unsubscribed previously or maybe the card was declined.
			#So create a new subscription to the existing customer
			subscription = customer.subscriptions.create({plan: new_plan})
		else
			#existing subscription found so it must be an upgrade or a downgrade
			current_subscription.plan = new_plan
			subscription = current_subscription.save
		end
		return subscription
	end 


end
