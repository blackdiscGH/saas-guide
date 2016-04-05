class SubscriptionsController < ApplicationController

	before_action :authenticate_user!

	def index
		@account = Account.find_by_email(current_user.email)
		logger.debug { "----->ENTERED Subscriptions_controller# INDEX"}
		logger.debug { "@account #{@account}" }
		logger.debug { "@account.active_until #{@account.active_until}" }
		logger.debug { "current_user #{current_user}" }
		logger.debug { "current_user.email #{current_user.email}" }
		logger.debug { "EXITED Subscriptions_controller# INDEX----->"}

	end

	def edit
		logger.debug { "----->ENTERED Subscriptions_controller# EDIT"}
		@account = Account.find(params[:id])
		@plans = Plan.all	
		logger.debug { "EXITED Subscriptions_controller# EDIT----->"}
	end 

	def update_card
		logger.debug { "----->ENTERED Subscriptions_controller# UPDATE CARD"}
		logger.debug { "EXITED Subscriptions_controller# UPDATE CARD----->"}
	end

	def update_card_details
		logger.debug { "----->ENTERED Subscriptions_controller# UPDATE CARD DETAILS"}
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

	logger.debug { "EXITED Subscriptions_controller# UPDATE CARD DETAILS----->"}
	end


	def create
		logger.debug { "----->ENTERED Subscriptions_controller# CREATE"}
		# Set your secret key: remember to change this to your live secret key in production
		# See your keys here https://dashboard.stripe.com/account/apikeys
		Stripe.api_key = "sk_test_52ACGAHGhXh8elFfA9GQ5xOf"

		logger.debug { "----->ENTERED Subscriptions_controller#create<-----"}
		

		# Get the credit card details submitted by the form
		token 			= params[:stripeToken]
		plan 			= params[:plan][:stripe_id]
		email 			= current_user.email
		current_account = Account.find_by_email(current_user.email)
		logger.debug {"Value of current_account: #{current_account}"}

		customer_id 	= current_account.customer_id
		logger.debug {"Value of customer_id: #{customer_id}"}

		current_plan 	= current_account.stripe_plan_id


		if customer_id.nil?
			#new customer
			# Create a STRIPE Customer Object
			logger.debug { "customer_id is nil !!!"}
			@customer = Stripe::Customer.create(
		  		:source => token,
		  		:plan => plan,
		  		:email => email
			)
		subscriptions = @customer.subscriptions
		@subscribed_plan = subscriptions.data.find {|o| o.plan.id == plan}

		else
			logger.debug { "customer_id is NOT nil !!!"}
			#Customer Exists on Stripe
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
		
		# Customer create with a valid subscription
		save_account_details(current_account, plan, @customer.id, active_until)

		logger.debug { "EXITED Subscriptions_controller# CREATE----->"}
		redirect_to :root, notice: "Successfully subsribed to a plan"

		rescue => e
			redirect_to :back, flash: {error: e.message}
	end

	def new
		logger.debug { "----->ENTERED Subscriptions_controller# NEW"}
		@plans = Plan.all
		logger.debug { "EXITED Subscriptions_controller# NEW----->"}
	end


	def cancel_subscription
		
		email 			= current_user.email
		current_account = Account.find_by_email(current_user.email)
		customer_id 	= current_account.customer_id
		current_plan 	= current_account.stripe_plan_id

		if current_plan.blank?
			raise "No plan found to be unsubscribed/cancelled"
		end

		#1. Fetch customer from stripe
		customer = Stripe::Customer.retrieve(customer_id)

		#2. Get current subscription from Stripe
		subscriptions = customer.subscriptions

		#3. Retrieve the subscription that you want to delete
		current_subscribed_plan = subscriptions.data.find {|o| o.plan.id == current_plan}
		if current_subscribed_plan.blank?
			raise "Subscription not found"
		end

		#4. Delete it
		current_subscribed_plan.delete 

		#5. Update the Local Account model
		save_account_details(current_account,"",customer_id, Time.at(0).to_datetime)
		@message = "Subscription cancelled successfully"
	
		rescue => e
			redirect_to "/subscriptions", flash: {error: "Error cancelling subscription" + e.message}
	end


	def save_account_details(account, plan, customer_id, active_until)
		logger.debug { "----->ENTERED save_account_details"}
		# Update the Account model with details
		account.stripe_plan_id 	= plan
		account.active_until 	= active_until
		account.customer_id 	= customer_id
		account.save
		logger.debug { "EXITED save_account_details ----->"}
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
