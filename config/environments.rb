ENV['SINATRA_ENV'] ||= "development"

require 'bundler/setup'
Bundler.require(:default, ENV['SINATRA_ENV'])

# model files must be required in a specific order
model_file_names = ["./app/models/rotate_maze.rb",
                    "./app/models/flip_maze.rb",
                    "./app/models/navigate_maze.rb",
                    "./app/models/solve_maze.rb",
                    "./app/models/board.rb",
                    "./app/models/maze.rb",
                    "./app/models/square.rb" ]

other_app_file_names = Dir.glob('./app/{helpers,controllers}/*.rb')

app_file_names = other_app_file_names + model_file_names

app_file_names.each { |file| require file }

configure :production, :development do
	db = URI.parse(ENV['DATABASE_URL'] || 'postgres://localhost/maze_craze')

	ActiveRecord::Base.establish_connection(
			:adapter => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
			:host     => db.host,
			:username => db.user,
			:password => db.password,
			:database => db.path[1..-1],
			:encoding => 'utf8'
	)
end