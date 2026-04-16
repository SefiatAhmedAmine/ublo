defmodule DBConnectionTest do
    def connect do
        {:ok, pid} = Postgrex.start_link(
            hostname: "localhost",
            username: "postgres",
            password: "root",
            database: "ublo_db")

        result = Postgrex.query!(pid, "SELECT NOW()", [])
        IO.inspect(result, label: "Connection successful, current time")
    end
end
