require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = PG.connect(dbname: "todos")
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(list_id)
    sql = "SELECT * FROM lists
            WHERE id = $1;"
    result = query(sql, list_id)
    
    return nil if result.ntuples == 0
    tuple = result.first
    {id: tuple["id"], name: tuple["name"], todos: []}
  end

  def all_lists
    sql = "SELECT * FROM lists;"
    result = query(sql)

    result.map do |tuple|
      {id: tuple["id"], name: tuple["name"], todos: []}
    end
  end

  def create_new_list(list_name)
    # list_id = next_element_id(@session[:lists])
    # @session[:lists] << { id: list_id, name: list_name, todos: [] }
  end

  def delete_list(list_id)
    # @session[:lists].reject! { |list| list[:id] == list_id }
  end
  
  def update_list_name(list_id, new_name)
    # list = find_list(list_id)
    # list[:name] = new_name
  end

  def create_new_todo(list_id, todo_name)
    # list = find_list(list_id)
    # todo_id = next_element_id(list[:todos])
    # list[:todos] << { id: todo_id, name: todo_name, completed: false }
  end

  def delete_todo_from_list(list_id, todo_id)
    # list = find_list(list_id)
    # list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, new_status)
    # list = find_list(list_id)
    # todo = list[:todos].find { |t| t[:id] == todo_id }
    # todo[:completed] = new_status
  end
  
  def mark_all_todos_as_completed(list_id)
    # list = find_list(list_id)
    # list[:todos].each { |todo| todo[:completed] = true }
  end

  # private

  # No longer needed since our database has auto-incrementing ids.
  # def next_element_id(collection)
  #   max = collection.map { |collection| collection[:id] }.max || 0
  #   max + 1
  # end

end