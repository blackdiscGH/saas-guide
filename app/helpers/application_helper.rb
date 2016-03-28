module ApplicationHelper
	def bootstrap_class_for flash_type
	
		case flash_type
		when "success" 
			"alert-success" # green
		when "error"
			"alert-danger" #red
		when "alert"
			"alert-warning" #yellow
		when "notice"
			"alert-info" #blue
		else
			flash_type.to_s
		end 
	
	end
end
