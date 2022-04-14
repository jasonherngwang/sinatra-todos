require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
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

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    
    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

=begin
GET  /lists                         => View all lists
GET  /lists/123                     => View a single list
GET  /lists/new                     => Form to create a new list
GET  /lists/123/edit                => Edit existing list
POST /lists                         => Create new list
POST /lists/123                     => Edit name of existing list
POST /lists/123/todos               => Add new todo to list
POST /lists/123/todos/123           => Update status of todo (completed/not completed)
POST /lists/123/todos/123/destroy   => Delete todo from list
POST /lists/123/destroy             => Delete list
POST /lists/123/complete_all        => Mark all todos as completed
=end

# View all lists
get "/lists" do
  @lists = session[:lists]

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
  elsif session[:lists].any? { |list| list[:name] == name }
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
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View single list
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Edit existing list
get "/lists/:list_id/edit" do
  list_id = params[:list_id].to_i
  @list = session[:lists][list_id]
  erb :edit_list, layout: :layout
end

# Edit list name
post "/lists/:list_id" do
  list_name = params[:list_name].strip
  list_id = params[:list_id].to_i
  @list = session[:lists][list_id]
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{list_id}"
  end
end

# Delete list
post "/lists/:list_id/destroy" do
  list_id = params[:list_id].to_i
  list_name = session[:lists][list_id][:name]
  session[:lists].delete_at list_id
  session[:success] = "The list '#{list_name}' has been deleted."
  redirect "/lists"
end

# Add new todo to list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip
  
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: text, completed: false }
    session[:success] = "The todo '#{params[:todo]}' has been added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete todo
post "/lists/:list_id/todos/:todo_id/destroy" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i
  todo_name = @list[:todos][todo_id][:name]
  @list[:todos].delete_at todo_id
  
  session[:success] = "The todo '#{todo_name}' has been deleted."
  redirect "/lists/#{@list_id}"
end

# Update status of a todo
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i
  todo_name = @list[:todos][todo_id][:name]
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed
  
  session[:success] = "The todo '#{todo_name}' has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos as completed
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  @list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end
