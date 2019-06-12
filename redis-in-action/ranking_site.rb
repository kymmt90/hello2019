require 'redis'

class RankingSite
  ARTICLES_PER_PAGE = 25
  ONE_WEEK_IN_SECONDS = 7 * 86400
  VOTE_SCORE = 432

  def vote_for_article(user, article)
    cutoff = Time.now.to_f - ONE_WEEK_IN_SECONDS

    return if connection.zscore('time:', article) < cutoff

    article_id = article.partition(':').last

    if connection.sadd("voted:#{article_id}", user)
      connection.zincrby('score:', VOTE_SCORE, article)
      connection.hincrby(article, 'votes', 1)
    end
  end

  def post_article(user, title, link)
    article_id = connection.incr('article').to_s

    voted = "voted:#{article_id}"
    connection.sadd(voted, user)
    connection.expire(voted, ONE_WEEK_IN_SECONDS)

    now = Time.now.to_f

    article = "article:#{article_id}"
    connection.hmset(article, 'title', title, 'link', link, 'poster', user, 'time', now, 'votes', 1)

    connection.zadd('score:', now + VOTE_SCORE, article)
    connection.zadd('time:', now, article)

    article_id
  end

  def get_articles(page, order = 'score:')
    first = (page - 1) * ARTICLES_PER_PAGE
    last = first + ARTICLES_PER_PAGE - 1
    ids = connection.zrevrange(order, first, last)

    articles = []
    ids.each do |id|
      article_data = connection.hgetall(id)
      article_data['id'] = id
      articles << article_data
    end

    articles
  end

  def add_remove_groups(article_id, to_add = [], to_remove = [])
    article = "article:#{article_id}"

    to_add.each do |group|
      connection.sadd("group:#{group}", article)
    end

    to_remove.each do |group|
      connection.srem("group:#{group}", article)
    end
  end

  def get_group_articles(group, page, order = 'score:')
    key = "#{order}#{group}"

    unless connection.exists(key)
      connection.zinterstore(key, ["group:#{group}", order], aggregate: 'max')
      connection.expire(key, 60)
    end

    get_articles(page, key)
  end

  private

  def connection
    @redis ||= Redis.new(host: 'localhost', port: 6379)
  end
end

ranking_site = RankingSite.new

ranking_site.post_article(
  'kymmt90',
  'active_record-type-encrypted_string',
  'https://blog.kymmt.com/entry/active_record-type-encrypted_string'
)

pp ranking_site.get_articles(1)

ranking_site.vote_for_article('kymmt90', 'article:11')

pp ranking_site.get_articles(1)
