# Codebase Structure

## Root Directory Structure
```
redmine_ai_helper/
├── app/                    # Rails MVC components
│   ├── controllers/        # AI helper controllers
│   ├── models/            # Data models (conversations, messages, settings, etc.)
│   ├── views/             # HTML templates and partials
│   └── helpers/           # View helpers
├── lib/                   # Core plugin logic
│   ├── redmine_ai_helper/ # Main plugin namespace
│   └── tasks/             # Rake tasks (vector.rake, scm.rake)
├── test/                  # Test suite
│   ├── unit/              # Unit tests (models, agents, tools)
│   └── functional/        # Controller tests
├── config/                # Configuration files
├── assets/                # CSS, JS, and prompt templates
├── db/                    # Database migrations
└── example/               # Example custom agent implementation
```

## Core Components (`lib/redmine_ai_helper/`)

### Agent System
- `base_agent.rb` - Foundation class with automatic registration
- `agents/` - Specialized agents (IssueAgent, RepositoryAgent, WikiAgent, etc.)
- `chat_room.rb` - Manages conversations and agent coordination

### LLM Integration
- `llm_client/` - Multiple LLM provider support (OpenAI, Anthropic, Gemini, Azure)
- `llm_provider.rb` - Provider abstraction
- `assistant.rb` - Extends Langchain::Assistant
- `assistants/` - Provider-specific implementations

### Tools and Utilities
- `tools/` - Agent-specific tools for operations
- `base_tools.rb` - Foundation for tool implementations
- `transport/` - MCP protocol support (STDIO, HTTP+SSE)
- `vector/` - Vector search with Qdrant integration
- `langfuse_util/` - LLM observability and monitoring

### Data Models (`app/models/`)
- `AiHelperConversation` - Chat conversations
- `AiHelperMessage` - Individual messages
- `AiHelperModelProfile` - AI model configurations
- `AiHelperSetting` - Global plugin settings
- `AiHelperProjectSetting` - Project-specific settings
- `AiHelperVectorData` - Vector embeddings
- `AiHelperSummaryCache` - Cached AI summaries

### Key Configuration
- `config/ai_helper/config.json` - MCP server configuration
- `config/ai_helper/config.yml` - Langfuse integration
- `assets/prompt_templates/` - Internationalized agent prompts (EN/JP)

## Dynamic Features
- Automatic agent registration via BaseAgent inheritance
- Dynamic SubMcpAgent generation per MCP server
- Custom agent development support (see `example/redmine_fortune/`)