# GitHub Copilot Instructions

## Code Writing
- Never write boilerplate code manually - always use code generation tools where applicable (e.g., OpenAPI codegen for API interfaces and models).
- Never update code in build directory

## Code Style
- Use Google Style for all code and other files.
- Use 2 space indentation for all files.
- For public methods, always add Javadoc comments.
- Use meaningful variable and method names that clearly express intent.
- Avoid magic numbers and strings - use constants with descriptive names.
- Do not hardcode numbers or strings that are reused within the same class; always extract them into a named constant or variable.
- Keep line length under 100 characters.

## Code Quality
- Don't duplicate yourself. Reuse code where possible (DRY principle).
- Extract common functionality into reusable methods or utility classes.
- Refactor classes and methods if they get too complex and large.
- Follow the Single Responsibility Principle - each class should have one reason to change.
- Keep methods focused and concise (ideally under 20 lines).
- Use dependency injection instead of direct instantiation.
- Favor composition over inheritance.
- Follow SOLID principles in object-oriented design.
- Avoid deep nesting (max 3 levels of indentation).
- Use early returns to reduce complexity and improve readability.

## Error Handling
- Always handle exceptions appropriately - never swallow exceptions silently.
- Use specific exception types rather than generic Exception.
- Log errors with sufficient context for debugging.
- Validate input parameters and fail fast with clear error messages.
- Use try-with-resources for automatic resource management.
- Don't use exceptions for control flow.

## Security Best Practices
- Never hardcode credentials, API keys, or sensitive data.
- Use environment variables or secure configuration management for secrets.
- Validate and sanitize all user inputs to prevent injection attacks.
- Use parameterized queries to prevent SQL injection.
- Implement proper authentication and authorization checks.
- Use HTTPS for all external communications.
- Keep dependencies up to date to avoid known vulnerabilities.
- Follow the principle of least privilege.

## Performance
- Avoid premature optimization - focus on clarity first.
- Use appropriate data structures for the use case.
- Consider lazy loading for expensive operations.
- Close resources properly to prevent memory leaks.
- Use caching strategically for frequently accessed data.
- Optimize database queries - avoid N+1 query problems.
- Use connection pooling for database connections.
- Profile before optimizing to identify actual bottlenecks.

## Documentation
- Write self-documenting code with clear names and structure.
- Add Javadoc comments for public APIs explaining purpose, parameters, return values, and exceptions.
- Document complex algorithms or non-obvious design decisions.
- Keep README files up to date with setup instructions and architecture overview.
- Document API endpoints with request/response examples.
- Avoid redundant comments that simply restate what the code does.

## Git Practices
- Write atomic commits - each commit should represent one logical change.
- Don't commit commented-out code or debug statements.
- Review your own code before creating a pull request.

# Functional Description
- [Functional Description](../functional_description.md)