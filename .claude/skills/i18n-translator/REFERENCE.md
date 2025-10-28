# i18n-translator Reference Guide

This reference document contains common patterns, resources, and examples for internationalizing Phoenix/Elixir applications with Gettext.

## Common Gettext Patterns

### Basic String Translation

```elixir
# In Elixir code
gettext("Hello, world!")

# In HEEx templates
<%= gettext("Welcome") %>
```

### String Interpolation

```elixir
# In Elixir code
gettext("Hello, %{name}!", name: user.name)

# In HEEx templates
<%= gettext("You have %{count} notifications", count: @notification_count) %>
```

### Pluralization

```elixir
# Basic plural
ngettext("1 item", "%{count} items", item_count, count: item_count)

# With context
ngettext(
  "You have 1 unread message",
  "You have %{count} unread messages",
  message_count,
  count: message_count
)
```

### Domain-Specific Translations

```elixir
# Using specific domain
dgettext("errors", "Invalid email address")
dgettext("admin", "User management")

# Plural with domain
dngettext("notifications", "1 new alert", "%{count} new alerts", count, count: count)
```

### Context-Aware Translations

Use domains or different keys for words with multiple meanings:

```elixir
# "Save" in different contexts
gettext("Save")              # Save button
dgettext("finance", "Save")  # Financial savings
gettext("Save changes")      # Explicit for clarity
```

## Translation File Structure

```
priv/gettext/
├── default.pot              # Template file (auto-generated)
├── fr/
│   └── LC_MESSAGES/
│       ├── default.po       # French translations
│       └── errors.po        # French error messages
└── it/
    └── LC_MESSAGES/
        ├── default.po       # Italian translations
        └── errors.po        # Italian error messages
```

## Common Translations

### UI Elements

| English | French | Italian |
|---------|--------|---------|
| Save | Enregistrer | Salva |
| Cancel | Annuler | Annulla |
| Delete | Supprimer | Elimina |
| Edit | Modifier | Modifica |
| Create | Créer | Crea |
| Update | Mettre à jour | Aggiorna |
| Close | Fermer | Chiudi |
| Submit | Soumettre | Invia |
| Search | Rechercher | Cerca |
| Filter | Filtrer | Filtra |
| Sort | Trier | Ordina |
| Loading | Chargement | Caricamento |
| Back | Retour | Indietro |
| Next | Suivant | Successivo |
| Previous | Précédent | Precedente |

### Form Labels

| English | French | Italian |
|---------|--------|---------|
| Email | E-mail | Email |
| Password | Mot de passe | Password |
| Username | Nom d'utilisateur | Nome utente |
| First name | Prénom | Nome |
| Last name | Nom | Cognome |
| Phone number | Numéro de téléphone | Numero di telefono |
| Address | Adresse | Indirizzo |
| City | Ville | Città |
| Country | Pays | Paese |
| Date of birth | Date de naissance | Data di nascita |

### Messages

| English | French | Italian |
|---------|--------|---------|
| Success | Succès | Successo |
| Error | Erreur | Errore |
| Warning | Avertissement | Avviso |
| Please wait | Veuillez patienter | Attendere prego |
| Are you sure? | Êtes-vous sûr ? | Sei sicuro? |
| Operation completed | Opération terminée | Operazione completata |
| Something went wrong | Une erreur s'est produite | Si è verificato un errore |

### Time and Dates

| English | French | Italian |
|---------|--------|---------|
| Today | Aujourd'hui | Oggi |
| Yesterday | Hier | Ieri |
| Tomorrow | Demain | Domani |
| Last week | La semaine dernière | La settimana scorsa |
| Next week | La semaine prochaine | La prossima settimana |
| %{count} days ago | Il y a %{count} jours | %{count} giorni fa |
| in %{count} hours | dans %{count} heures | tra %{count} ore |

## Pluralization Rules

### French Pluralization

French has two forms:
- Singular: n == 0 or n == 1
- Plural: n > 1

```elixir
ngettext("1 fichier", "%{count} fichiers", count, count: count)
```

### Italian Pluralization

Italian has two forms:
- Singular: n == 1
- Plural: n != 1

```elixir
ngettext("1 file", "%{count} file", count, count: count)
```

## HTML in Translations

### Safe HTML

```elixir
# Mark as safe when HTML is intentional
gettext("Read our <strong>terms</strong>") |> raw()
```

### Avoid HTML in Translations (Preferred)

```heex
<%= gettext("Read our") %>
<strong><%= gettext("terms") %></strong>
```

## Migration Commands

```bash
# Extract strings from code to POT files
mix gettext.extract

# Merge POT changes into PO files
mix gettext.merge priv/gettext

# Merge and update for specific locale
mix gettext.merge priv/gettext --locale fr

# Check for missing translations
mix gettext.check

# Extract and merge in one command
mix gettext.extract --merge
```

## Best Practices

### DO

✓ Use descriptive msgids (keys should be the English text)
✓ Keep strings complete (don't split sentences)
✓ Include context in interpolation variable names
✓ Use domains to organize translations by feature
✓ Test pluralization with edge cases (0, 1, 2, many)
✓ Provide translator comments for ambiguous strings

### DON'T

✗ Concatenate translated strings
✗ Translate technical terms or API keys
✗ Translate HTML attributes like `aria-label` keys
✗ Split sentences for styling (use HTML outside gettext)
✗ Use abbreviated or cryptic msgids
✗ Hard-code punctuation that varies by language

## Debugging Tips

### Missing Translation

If a translation is missing, Gettext will:
1. Log a warning in development
2. Return the msgid (English text) as fallback

### Check Current Locale

```elixir
Gettext.get_locale(PremiereEcouteWeb.Gettext)
```

### Set Locale

```elixir
# Set locale for current process
Gettext.put_locale(PremiereEcouteWeb.Gettext, "fr")

# Set locale in controller
plug :put_locale

defp put_locale(conn, _opts) do
  locale = get_session(conn, :locale) || "en"
  Gettext.put_locale(PremiereEcouteWeb.Gettext, locale)
  conn
end
```

## Resources

- [Gettext Documentation](https://hexdocs.pm/gettext/Gettext.html)
- [Phoenix Internationalization Guide](https://hexdocs.pm/phoenix/Phoenix.Controller.html#module-i18n)
- [Elixir Gettext GitHub](https://github.com/elixir-gettext/gettext)
- [Unicode CLDR Plural Rules](https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html)

---

**AIDEV-NOTE:** Quick reference for common i18n patterns and translations. Load this when you need specific examples or translation lookups.
