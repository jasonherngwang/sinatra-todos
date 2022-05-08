require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: "todos")
    end
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(list_id)
    sql = <<~SQL
      SELECT * FROM lists
       WHERE id = $1;
    SQL
    sql = <<~SQL
      SELECT lists.*,
             count(todos.id) AS todos_count,
             count(NULLIF(todos.completed, true)) AS todos_remaining_count
        FROM lists
        LEFT JOIN todos
          ON lists.id = todos.list_id
       WHERE lists.id = $1
       GROUP BY lists.id
       ORDER BY lists.name;
    SQL
    result = query(sql, list_id)

    return nil if result.ntuples == 0

    tuple_to_list_hash(result.first)
  end

  def find_todos_in_list(list_id)
    sql = <<~SQL
      SELECT * FROM todos
       WHERE list_id = $1;
    SQL
    result = query(sql, list_id)
    return [] if result.ntuples == 0

    result.map do |tuple|
      { id: tuple["id"].to_i, 
        name: tuple["name"],
        completed: tuple["completed"] == "t" }
    end
  end

  def all_lists
    sql = <<~SQL
      SELECT lists.*,
             count(todos.id) AS todos_count,
             count(NULLIF(todos.completed, true)) AS todos_remaining_count
        FROM lists
        LEFT JOIN todos
          ON lists.id = todos.list_id
       GROUP BY lists.id
       ORDER BY lists.name;
    SQL
    result = query(sql)

    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

  def create_new_list(list_name)
    sql = <<~SQL
      INSERT INTO lists (name)
      VALUES ($1);
    SQL
    query(sql, list_name)
  end

  def delete_list(list_id)
    sql = <<~SQL
      DELETE FROM lists
       WHERE id = $1;
    SQL
    query(sql, list_id)
  end
  
  def update_list_name(list_id, new_name)
    sql = <<~SQL
      UPDATE lists
         SET name = $1
       WHERE id = $2;
    SQL
    query(sql, new_name, list_id)
  end

  def create_new_todo(list_id, todo_name)
    sql = <<~SQL
      INSERT INTO todos (name, list_id)
      VALUES ($1, $2);
    SQL
    query(sql, todo_name, list_id)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = <<~SQL
      DELETE FROM todos
       WHERE id = $1
         AND list_id = $2;
    SQL
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = <<~SQL
      UPDATE todos
         SET completed = $1
       WHERE id = $2
         AND list_id = $3;
    SQL
    query(sql, new_status, todo_id, list_id)
  end
  
  def mark_all_todos_as_completed(list_id)
    sql = <<~SQL
      UPDATE todos
         SET completed = true
       WHERE list_id = $1;
    SQL
    query(sql, list_id)
  end

  def disconnect
    @db.close
  end

  private

  def tuple_to_list_hash(tuple)
    { id: tuple["id"].to_i, 
      name: tuple["name"], 
      todos_count: tuple["todos_count"].to_i,
      todos_remaining_count: tuple["todos_remaining_count"].to_i }
  end
end