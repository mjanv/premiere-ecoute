# i18n-translator Examples

Real-world examples of internationalizing Phoenix/Elixir code with Gettext.

## Example 1: LiveView Registration Form

### Before

```heex
<div class="form-container">
  <h1>Create Account</h1>
  <p>Sign up to get started</p>

  <.form for={@form} phx-submit="register">
    <.input field={@form[:email]} type="email" label="Email address" required />
    <.input field={@form[:password]} type="password" label="Password" required />
    <.input field={@form[:password_confirmation]} type="password" label="Confirm password" required />

    <:actions>
      <.button type="submit">Create my account</.button>
    </:actions>
  </.form>

  <p>
    Already have an account?
    <.link navigate={~p"/login"}>Sign in</.link>
  </p>
</div>
```

### After

```heex
<div class="form-container">
  <h1><%= gettext("Create Account") %></h1>
  <p><%= gettext("Sign up to get started") %></p>

  <.form for={@form} phx-submit="register">
    <.input field={@form[:email]} type="email" label={gettext("Email address")} required />
    <.input field={@form[:password]} type="password" label={gettext("Password")} required />
    <.input field={@form[:password_confirmation]} type="password" label={gettext("Confirm password")} required />

    <:actions>
      <.button type="submit"><%= gettext("Create my account") %></.button>
    </:actions>
  </.form>

  <p>
    <%= gettext("Already have an account?") %>
    <.link navigate={~p"/login"}><%= gettext("Sign in") %></.link>
  </p>
</div>
```

### Translation Files

**priv/gettext/fr/LC_MESSAGES/default.po:**
```po
msgid "Create Account"
msgstr "Créer un compte"

msgid "Sign up to get started"
msgstr "Inscrivez-vous pour commencer"

msgid "Email address"
msgstr "Adresse e-mail"

msgid "Password"
msgstr "Mot de passe"

msgid "Confirm password"
msgstr "Confirmer le mot de passe"

msgid "Create my account"
msgstr "Créer mon compte"

msgid "Already have an account?"
msgstr "Vous avez déjà un compte ?"

msgid "Sign in"
msgstr "Se connecter"
```

**priv/gettext/it/LC_MESSAGES/default.po:**
```po
msgid "Create Account"
msgstr "Crea account"

msgid "Sign up to get started"
msgstr "Registrati per iniziare"

msgid "Email address"
msgstr "Indirizzo email"

msgid "Password"
msgstr "Password"

msgid "Confirm password"
msgstr "Conferma password"

msgid "Create my account"
msgstr "Crea il mio account"

msgid "Already have an account?"
msgstr "Hai già un account?"

msgid "Sign in"
msgstr "Accedi"
```

## Example 2: Error Handling in Controller

### Before

```elixir
defmodule PremiereEcouteWeb.UserController do
  use PremiereEcouteWeb, :controller

  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: ~p"/users/#{user}")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, "Failed to create user. Please check the errors below.")
        |> render(:new, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)

    case Accounts.delete_user(user) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User deleted successfully.")
        |> redirect(to: ~p"/users")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Cannot delete this user.")
        |> redirect(to: ~p"/users/#{id}")
    end
  end
end
```

### After

```elixir
defmodule PremiereEcouteWeb.UserController do
  use PremiereEcouteWeb, :controller

  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, gettext("User created successfully."))
        |> redirect(to: ~p"/users/#{user}")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, gettext("Failed to create user. Please check the errors below."))
        |> render(:new, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)

    case Accounts.delete_user(user) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, gettext("User deleted successfully."))
        |> redirect(to: ~p"/users")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, gettext("Cannot delete this user."))
        |> redirect(to: ~p"/users/#{id}")
    end
  end
end
```

## Example 3: Validation Messages with Interpolation

### Before

```elixir
defmodule PremiereEcoute.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :username, :string
    field :age, :integer

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :age])
    |> validate_required([:email, :username], message: "can't be blank")
    |> validate_format(:email, ~r/@/, message: "must be a valid email")
    |> validate_length(:username, min: 3, max: 20, message: "must be between 3 and 20 characters")
    |> validate_number(:age, greater_than_or_equal_to: 13, message: "must be at least 13")
    |> unique_constraint(:email, message: "has already been taken")
  end
end
```

### After

```elixir
defmodule PremiereEcoute.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import PremiereEcouteWeb.Gettext

  schema "users" do
    field :email, :string
    field :username, :string
    field :age, :integer

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :age])
    |> validate_required([:email, :username], message: gettext("can't be blank"))
    |> validate_format(:email, ~r/@/, message: gettext("must be a valid email"))
    |> validate_length(:username,
        min: 3,
        max: 20,
        message: gettext("must be between %{min} and %{max} characters", min: 3, max: 20)
      )
    |> validate_number(:age,
        greater_than_or_equal_to: 13,
        message: gettext("must be at least %{count}", count: 13)
      )
    |> unique_constraint(:email, message: gettext("has already been taken"))
  end
end
```

## Example 4: Pluralization in Dashboard

### Before

```elixir
defmodule PremiereEcouteWeb.DashboardLive do
  use PremiereEcouteWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="dashboard">
      <h1>Dashboard</h1>

      <div class="stats">
        <div class="stat-card">
          <span class="stat-label">Active Users</span>
          <span class="stat-value"><%= @active_users %></span>
          <span class="stat-description">
            <%= if @active_users == 1 do %>
              1 user online
            <% else %>
              <%= @active_users %> users online
            <% end %>
          </span>
        </div>

        <div class="stat-card">
          <span class="stat-label">Pending Invitations</span>
          <span class="stat-value"><%= @pending_invites %></span>
          <span class="stat-description">
            <%= if @pending_invites == 1 do %>
              1 invitation sent
            <% else %>
              <%= @pending_invites %> invitations sent
            <% end %>
          </span>
        </div>
      </div>
    </div>
    """
  end
end
```

### After

```elixir
defmodule PremiereEcouteWeb.DashboardLive do
  use PremiereEcouteWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="dashboard">
      <h1><%= gettext("Dashboard") %></h1>

      <div class="stats">
        <div class="stat-card">
          <span class="stat-label"><%= gettext("Active Users") %></span>
          <span class="stat-value"><%= @active_users %></span>
          <span class="stat-description">
            <%= ngettext("1 user online", "%{count} users online", @active_users, count: @active_users) %>
          </span>
        </div>

        <div class="stat-card">
          <span class="stat-label"><%= gettext("Pending Invitations") %></span>
          <span class="stat-value"><%= @pending_invites %></span>
          <span class="stat-description">
            <%= ngettext("1 invitation sent", "%{count} invitations sent", @pending_invites, count: @pending_invites) %>
          </span>
        </div>
      </div>
    </div>
    """
  end
end
```

## Example 5: Dynamic Content with Context

### Before

```elixir
defmodule PremiereEcouteWeb.NotificationLive do
  use PremiereEcouteWeb, :live_view

  def render_notification(assigns) do
    ~H"""
    <div class="notification">
      <%= case @notification.type do %>
        <% :comment -> %>
          <p><%= @notification.user.name %> commented on your post</p>
        <% :like -> %>
          <p><%= @notification.user.name %> liked your post</p>
        <% :follow -> %>
          <p><%= @notification.user.name %> started following you</p>
        <% :mention -> %>
          <p><%= @notification.user.name %> mentioned you in a comment</p>
      <% end %>
      <span class="time"><%= format_time_ago(@notification.inserted_at) %> ago</span>
    </div>
    """
  end

  defp format_time_ago(timestamp) do
    diff = DateTime.diff(DateTime.utc_now(), timestamp, :minute)

    cond do
      diff < 1 -> "Just now"
      diff < 60 -> "#{diff} minutes"
      diff < 1440 -> "#{div(diff, 60)} hours"
      true -> "#{div(diff, 1440)} days"
    end
  end
end
```

### After

```elixir
defmodule PremiereEcouteWeb.NotificationLive do
  use PremiereEcouteWeb, :live_view

  def render_notification(assigns) do
    ~H"""
    <div class="notification">
      <%= case @notification.type do %>
        <% :comment -> %>
          <p><%= gettext("%{name} commented on your post", name: @notification.user.name) %></p>
        <% :like -> %>
          <p><%= gettext("%{name} liked your post", name: @notification.user.name) %></p>
        <% :follow -> %>
          <p><%= gettext("%{name} started following you", name: @notification.user.name) %></p>
        <% :mention -> %>
          <p><%= gettext("%{name} mentioned you in a comment", name: @notification.user.name) %></p>
      <% end %>
      <span class="time"><%= format_time_ago(@notification.inserted_at) %></span>
    </div>
    """
  end

  defp format_time_ago(timestamp) do
    diff = DateTime.diff(DateTime.utc_now(), timestamp, :minute)

    cond do
      diff < 1 ->
        gettext("Just now")
      diff < 60 ->
        ngettext("1 minute ago", "%{count} minutes ago", diff, count: diff)
      diff < 1440 ->
        hours = div(diff, 60)
        ngettext("1 hour ago", "%{count} hours ago", hours, count: hours)
      true ->
        days = div(diff, 1440)
        ngettext("1 day ago", "%{count} days ago", days, count: days)
    end
  end
end
```

## Example 6: Email Templates

### Before

```elixir
defmodule PremiereEcoute.Mailer.WelcomeEmail do
  import Swoosh.Email

  def welcome_email(user) do
    new()
    |> to({user.name, user.email})
    |> from({"Premiere Ecoute", "noreply@premiereEcoute.com"})
    |> subject("Welcome to Premiere Ecoute!")
    |> html_body("""
      <h1>Welcome, #{user.name}!</h1>
      <p>Thank you for joining Premiere Ecoute. We're excited to have you on board.</p>
      <p>To get started, please verify your email address by clicking the button below:</p>
      <a href="#{user.verification_url}" style="background: #3b82f6; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px;">
        Verify Email
      </a>
      <p>If you didn't create this account, you can safely ignore this email.</p>
      <p>Best regards,<br>The Premiere Ecoute Team</p>
    """)
  end
end
```

### After

```elixir
defmodule PremiereEcoute.Mailer.WelcomeEmail do
  import Swoosh.Email
  import PremiereEcouteWeb.Gettext

  def welcome_email(user) do
    # AIDEV-NOTE: Email locale should be set based on user preference
    Gettext.put_locale(PremiereEcouteWeb.Gettext, user.locale || "en")

    new()
    |> to({user.name, user.email})
    |> from({"Premiere Ecoute", "noreply@premiereEcoute.com"})
    |> subject(gettext("Welcome to Premiere Ecoute!"))
    |> html_body("""
      <h1>#{gettext("Welcome, %{name}!", name: user.name)}</h1>
      <p>#{gettext("Thank you for joining Premiere Ecoute. We're excited to have you on board.")}</p>
      <p>#{gettext("To get started, please verify your email address by clicking the button below:")}</p>
      <a href="#{user.verification_url}" style="background: #3b82f6; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px;">
        #{gettext("Verify Email")}
      </a>
      <p>#{gettext("If you didn't create this account, you can safely ignore this email.")}</p>
      <p>#{gettext("Best regards,")}<br>#{gettext("The Premiere Ecoute Team")}</p>
    """)
  end
end
```

## Common Patterns Summary

| Pattern | Use Case | Example |
|---------|----------|---------|
| `gettext/1` | Simple strings | `gettext("Save")` |
| `gettext/2` | String with interpolation | `gettext("Hello %{name}", name: user.name)` |
| `ngettext/4` | Pluralization | `ngettext("1 item", "%{count} items", count, count: count)` |
| `dgettext/2` | Domain-specific | `dgettext("errors", "Invalid format")` |
| `dngettext/5` | Domain + plural | `dngettext("admin", "1 user", "%{count} users", count, count: count)` |
| Attribute translation | Form labels | `label={gettext("Email")}` |
| HTML safety | Trusted HTML | `gettext("Click <strong>here</strong>") \|> raw()` |

---

**AIDEV-NOTE:** Load these examples when working on similar internationalization tasks. They demonstrate real-world patterns from Phoenix applications.
