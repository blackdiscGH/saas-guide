namespace :data do
  desc "Delete the last record in User and Account"
  task del_last: :environment do
  	Account.last.destroy
  	User.last.destroy
  end

end
