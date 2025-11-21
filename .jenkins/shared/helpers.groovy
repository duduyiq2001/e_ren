// Shared Helper Functions for Jenkins Pipelines

def waitForPostgres(int timeout = 30) {
  sh """
    timeout ${timeout} sh -c 'until PGPASSWORD=password psql -h postgres -U postgres -c "\\\\q" 2>/dev/null; do
      echo "Waiting for postgres..."
      sleep 1
    done'
    echo "Postgres is ready!"
  """
}

def setupDatabase() {
  sh '''
    bundle exec rails db:create RAILS_ENV=test
    bundle exec rails db:schema:load RAILS_ENV=test
  '''
}

def installBundler() {
  sh '''
    gem install bundler -v '~> 2.4'
    bundle config set --local path 'vendor/bundle'
    bundle install --jobs 4 --retry 3
  '''
}

def runRspec(String pattern = '', String outputFile = 'test-results/rspec.xml') {
  def rspecCmd = "bundle exec rspec"

  if (pattern) {
    rspecCmd += " ${pattern}"
  }

  rspecCmd += """
    --format progress \\
    --format RspecJunitFormatter \\
    --out ${outputFile}
  """

  sh rspecCmd
}

def runRubocop() {
  sh 'bundle exec rubocop --format simple'
}

def notifyGitHub(String context, String status, String description = '') {
  if (description == '') {
    description = status == 'PENDING' ? 'Running...' :
                  status == 'SUCCESS' ? 'Passed' : 'Failed'
  }

  githubNotify(
    context: context,
    description: description,
    status: status,
    targetUrl: env.BUILD_URL
  )
}

return this
