# Prints a single-use magic-link login token for PW_USER, minted inside the running dev node.
# Needs the app running as `iex --sname dev -S mix` (node `dev@<short hostname>`, the project default).
# Dev only: aborts unless the remote node reports Mix.env() == :dev.
user = System.fetch_env!("PW_USER")
host = hd(String.split(to_string(:net_adm.localhost()), "."))
node = String.to_atom(System.get_env("PW_NODE") || "dev@#{host}")
call = fn m, f, a ->
  case :rpc.call(node, m, f, a) do
    {:badrpc, reason} -> IO.puts(:stderr, "rpc to #{node} failed: #{inspect(reason)}"); System.halt(2)
    result -> result
  end
end

if call.(Mix, :env, []) != :dev, do: (IO.puts(:stderr, "refusing: #{node} is not a dev node"); System.halt(3))

schema = PremiereEcoute.Accounts.User
case call.(PremiereEcoute.Repo, :get_by, [schema, [username: user]]) do
  nil -> IO.puts(:stderr, "no user #{inspect(user)}"); System.halt(4)
  u ->
    {:ok, %{text_body: token}} = call.(PremiereEcoute.Accounts, :deliver_login_instructions, [u, & &1])
    IO.puts(token)
end
