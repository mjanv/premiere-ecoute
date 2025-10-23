# Security Policy

## Supported Versions

We release patches for security vulnerabilities for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| < main  | :x:                |

Currently, security updates are applied to the `main` branch. We recommend always using the latest version from the main branch.

## Reporting a Vulnerability

We take the security of Premiere Ecoute seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### How to Report a Security Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via GitHub's Security Advisory feature:

1. Go to the [Security tab](../../security/advisories) of this repository
2. Click "Report a vulnerability"
3. Fill out the advisory form with as much detail as possible

Alternatively, you can email the maintainers directly. Please include the following information:

- Type of issue (e.g., buffer overflow, SQL injection, cross-site scripting, etc.)
- Full paths of source file(s) related to the manifestation of the issue
- The location of the affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

This information will help us triage your report more quickly.

### What to Expect

After you submit a report, you can expect the following:

- **Acknowledgment**: We will acknowledge receipt of your vulnerability report within 48 hours
- **Initial Assessment**: We will provide an initial assessment of the report within 5 business days
- **Status Updates**: We will keep you informed about our progress as we work on a fix
- **Resolution**: Once the vulnerability is resolved, we will notify you and publicly disclose the issue (with credit to you, if desired)

### Disclosure Policy

- We request that you give us reasonable time to address the vulnerability before any public disclosure
- We will work with you to understand and resolve the issue promptly
- Once a fix is available, we will publish a security advisory
- We will credit security researchers who report valid vulnerabilities (unless they prefer to remain anonymous)

## Security Best Practices

### For Users

When deploying Premiere Ecoute, please follow these security best practices:

1. **Environment Variables**: Never commit `.env` files or expose API credentials
2. **HTTPS**: Always use HTTPS in production environments
3. **Database**: Use strong passwords for database access and restrict network access
4. **Updates**: Keep dependencies up to date by regularly running `mix hex.outdated`
5. **Secrets**: Use secure secret key bases and regularly rotate sensitive credentials
6. **OAuth**: Properly configure OAuth redirect URIs to prevent authorization code interception

### For Contributors

When contributing to Premiere Ecoute, please:

1. **Dependencies**: Be cautious when adding new dependencies; review their security history
2. **Code Review**: Follow secure coding practices and participate in code reviews
3. **Static Analysis**: Run `mix sobelow` before submitting pull requests to catch common vulnerabilities
4. **Secrets**: Never include API keys, tokens, or other secrets in code or commits
5. **Input Validation**: Always validate and sanitize user input
6. **SQL Injection**: Use parameterized queries via Ecto; never build raw SQL from user input

## Security Audit Tools

This project uses several tools to maintain security:

```bash
mix sobelow        # Detect common security vulnerabilities
mix deps.audit     # Scan for security vulnerabilities in dependencies
mix audit          # Run all auditing checks
```

Please run these tools before submitting contributions.

## Scope

### In Scope

The following are within the scope of our security policy:

- Authentication and authorization vulnerabilities
- Data injection attacks (SQL, XSS, etc.)
- Credential exposure or improper storage
- Session management issues
- API security vulnerabilities
- Dependencies with known vulnerabilities

### Out of Scope

The following are explicitly out of scope:

- Denial of service attacks requiring significant resources
- Issues in third-party services (Spotify, Twitch APIs)
- Social engineering attacks
- Physical attacks
- Issues requiring physical access to servers

## Known Security Considerations

### API Integrations

Premiere Ecoute integrates with external services:

- **Spotify API**: OAuth 2.0 authentication, API rate limiting
- **Twitch API**: OAuth 2.0 authentication, webhook verification, chat integration

Please ensure:
- OAuth tokens are stored securely and never exposed in logs or error messages
- Webhook signatures are properly validated (Twitch webhooks use HMAC verification)
- API credentials are rotated if compromised

### Development vs Production

- **Development**: Uses mock servers for some Twitch functionality (localhost:4001)
- **Production**: Ensure all API endpoints point to production services
- Never use development credentials in production

## Additional Resources

- [OWASP Top Ten](https://owasp.org/www-project-top-ten/)
- [Elixir Security Working Group](https://erlef.org/wg/security)
- [Phoenix Security Best Practices](https://hexdocs.pm/phoenix/security.html)
- [Ecto SQL Injection Prevention](https://hexdocs.pm/ecto/Ecto.Query.html#module-query-safety)

## Contact

For security-related questions that are not vulnerabilities, please open a public issue or discussion on GitHub.

---

Thank you for helping keep Premiere Ecoute and its users safe!
