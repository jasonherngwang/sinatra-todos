require 'dotenv/load'
require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"

require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET']
  set :erb, :escape_html => true
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    
    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

def load_list(list_id)
  list = @storage.find_list(list_id)
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

before do
  @storage = DatabasePersistence.new(logger)
end

get "/" do
  redirect "/lists"
end

# View all lists
get "/lists" do
  # @lists = session[:lists]
  @lists = @storage.all_lists

  erb :lists, layout: :layout
end

# Render new list input form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return nil if input invalid, error message if valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    "List name must be unique. List '#{name}' already exists."
  end
end

# Return nil if input invalid, error message if valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters."
  end
end

# Create new list
post "/lists" do
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)

    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View single list
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Edit existing list
get "/lists/:list_id/edit" do
  list_id = params[:list_id].to_i
  @list = load_list(list_id)
  erb :edit_list, layout: :layout
end

# Edit list name
post "/lists/:list_id" do
  list_name = params[:list_name].strip
  list_id = params[:list_id].to_i
  @list = load_list(list_id)
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(list_id, list_name)
    session[:success] = "The list has been updated."
    redirect "/lists/#{list_id}"
  end
end

# Delete list
post "/lists/:list_id/destroy" do
  list_id = params[:list_id].to_i
  @list = load_list(list_id)
  
  @storage.delete_list(list_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list '#{@list[:name]}' has been deleted."
    redirect "/lists"
  end
end

# Add new todo to list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip
  
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, text)

    session[:success] = "The todo '#{params[:todo]}' has been added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete todo
post "/lists/:list_id/todos/:todo_id/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i
  todo = @list[:todos].select { |todo| todo[:id] == todo_id }.first

  @storage.delete_todo_from_list(@list_id, todo_id)

  @list[:todos].delete(todo)
  
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo '#{todo[:name]}' has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update status of a todo
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  is_completed = params[:completed] == "true"

  @storage.update_todo_status(@list_id, todo_id, is_completed)

  session[:success] = "The todo '#{todo[:name]}' has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos as completed
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @storage.mark_all_todos_as_completed(@list_id)

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end

after do
  @storage.disconnect
end
