require 'jira'

module ErrbitJiraPlugin
  class IssueTracker < ErrbitPlugin::IssueTracker
    LABEL = 'jira'

    NOTE = 'Please configure Jira by entering the information below.'

    FIELDS = [
        [:base_url, {
            :label => 'Jira URL without trailing slash',
            :placeholder => 'https://jira.example.org'
        }],
        [:context_path, {
            :optional => true,
            :label => 'Context Path (Just "/" if empty otherwise with leading slash)',
            :placeholder => "/jira"
        }],
        [:username, {
            :label => 'Username',
            :placeholder => 'johndoe'
        }],
        [:password, {
            :label => 'Password',
            :placeholder => 'p@assW0rd'
        }],
        [:project_id, {
            :label => 'Project Key',
            :placeholder => 'The project Key where the issue will be created'
        }],
        [:issue_priority, {
            :label => 'Priority',
            :placeholder => 'Normal'
        }]
    ]

    def self.label
      LABEL
    end

    def self.note
      NOTE
    end

    def self.fields
      FIELDS
    end

    def self.icons
      @icons ||= {
        active: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_active.png')
        ],
        create: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_create.png')
        ],
        goto: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_goto.png'),
        ],
        inactive: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_inactive.png'),
        ]
      }
    end

    def self.body_template
      @body_template ||= ERB.new(File.read(
        File.join(
          ErrbitJiraPlugin.root, 'views', 'jira_issues_body.txt.erb'
        )
      ))
    end

    def configured?
      options['project_id'].present?
    end

    def errors
      errors = []
      if self.class.fields.detect {|f| options[f[0]].blank?  && !f[1][:optional]}
        errors << [:base, 'You must specify all non optional values!']
      end
      errors
    end

    def comments_allowed?
      false
    end

    def client
      params = {
        :username => options['username'],
        :password => options['password'],
        :site => options['base_url'],
        :auth_type => :basic,
        :context_path => (options['context_path'] == '/') ? options['context_path'] = '' : options['context_path']
      }
      JIRA::Client.new(params)
    end

    def create_issue(title, body, user: {})
      begin
        issue_title =  title
        issue_description = body
        issue = {"fields"=>{"summary"=>issue_title.squish,
                            "description"=>issue_description,
                            "project"=>{"key"=>options['project_id']},
                            "issuetype"=>{"id"=>"3"},
                            "priority"=>{"name"=>options['issue_priority']}}}

        issue_build = client.Issue.build
        issue_build.save(issue)

        jira_url(issue_build.key)

      rescue JIRA::HTTPError => e
        raise ErrbitJiraPlugin::IssueError, e.response.body
      end
    end

    def jira_url(key)
      "#{options['base_url']}#{ctx_path}browse/#{options['project_id']}/issues/#{key}"
    end

    def ctx_path
      (options['context_path'] == '') ? '/' : options['context_path']
    end

    def url
      options['base_url']
    end
  end
end
