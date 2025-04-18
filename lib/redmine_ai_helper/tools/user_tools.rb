require "redmine_ai_helper/base_tools"

module RedmineAiHelper
  module Tools
    class UserTools < RedmineAiHelper::BaseTools
      define_function :list_users, description: "Returns a list of all users who have logged in within the past year. The user information includes the following items: id, login, firstname, lastname, created_on, last_login_on." do
        property :query, type: "object", description: "The query to filter the users.", required: true do
          property :limit, type: "integer", description: "The maximum number of users to return. The default is 100."
          property :status, type: "string", enum: ["active", "locked", "registered"], description: "The status of the users to return. The default is 'active'."
          property :date_fields, type: "array", description: "The date fields to filter on." do
            item type: "object", description: "The date field" do
              property :field_name, type: "string", enum: ["created_on", "last_login_on"], description: "The date field to filter on.", required: true
              property :operator, type: "string", enum: ["=", "!=", ">", "<", ">=", "<="], description: "The operator to use for the filter.", required: true
              property :value, type: "string", description: "The value to filter on.", required: true
            end
          end
          property :sort, type: "object", description: "The field to sort on." do
            property :field_name, type: "string", enum: ["id", "login", "firstname", "lastname", "created_on", "last_login_on"], description: "The field to sort on.", required: true
            property :order, type: "string", enum: ["asc", "desc"], description: "The order to sort in.", required: true
          end
        end
      end
      # list_users
      # args: { query: { limit: 100, status: "active", date_fields: [], sort: { field_name: "last_login_on", order: "desc" } } }
      # args: { query: { limit: 100, status: "active", date_fields: [], sort: { field_name: "last_login_on", order: "desc" } } }
      # Returns a list of all users who have logged in within the past year
      def list_users(query: {})
        limit = query[:limit] || 100
        status = query[:status] || "active"
        status_value = { "active" => 1, "registered" => 2, "locked" => 3 }
        date_fields = query[:date_fields] || []
        sort = query[:sort] || { field_name: "last_login_on", order: "desc" }

        users = User.where(type: "User").where(status: status_value[status]).order(sort[:field_name] => sort[:order])

        date_fields.each do |date_field|
          field_name = date_field[:field_name]
          operator = date_field[:operator]
          value = date_field[:value]
          if ["<", "<="].include?(operator)
            users = users.where("#{field_name} #{operator} ? OR #{field_name} IS NULL", value)
          else
            users = users.where("#{field_name} #{operator} ?", value)
          end
        end

        count = users.count
        users = users.limit(limit)
        user_list = []
        users.map do |user|
          user_list <<
          {
            id: user.id,
            login: user.login,
            firstname: user.firstname,
            lastname: user.lastname,
            created_on: user.created_on,
            last_login_on: user.last_login_on,
          }
        end
        json = { users: user_list, total: count }
        json
      end

      define_function :find_user, description: "Returns a list of users that match the name or login. The user information includes the following items: id, login, firstname, lastname, created_on, last_login_on." do
        property :name, type: "string", description: "The user name to search for.", required: true
      end
      # Returns a list of users that match the name or login
      # args: { name: "string" }
      def find_user(name:)
        users = User.all.filter { |user|
          user.login.downcase.include?(name.downcase) || user.name.downcase.include?(name.downcase)
        }
        user_list = []
        users.map do |user|
          user_list <<
          {
            id: user.id,
            login: user.login,
            firstname: user.firstname,
            lastname: user.lastname,
            created_on: user.created_on,
            last_login_on: user.last_login_on,
          }
        end
        json = { users: user_list }
        json
      end
    end
  end
end
