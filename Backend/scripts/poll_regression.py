"""Poll HTTP regression against disposable PostgreSQL; never modifies the local app DB."""
from pathlib import Path
from datetime import datetime, timedelta, timezone
from concurrent.futures import ThreadPoolExecutor
import sys
import uuid
import api_regression as suite

suite.TARGET = Path(__file__).resolve().parents[1] / 'target/poll-regression'


def polls(self):
    self.setup()
    base = '/api/creator/polls'
    body = {'question': 'Chủ đề tiếp theo?', 'options': ['Bạch Đằng', 'Lam Sơn'],
            'seriesId': None, 'podcastId': None, 'startsAt': None, 'endsAt': None}
    self.get(base, 'creator_test')
    detail = self.post(base, 'creator_test', body, expected=201)
    pid = detail['poll']['pollId']
    path = f'{base}/{pid}'
    self.check(detail['poll']['seriesId'] is None and detail['poll']['podcastId'] is None,
               'Channel poll permits null series and podcast')
    self.check(self.sql(f'''SELECT count(*) FROM "Polll_questions" WHERE poll_id='{pid}';''') == '2',
               'Create persists poll and two options in PostgreSQL')
    self.get(path, 'creator_test')
    self.get(path, 'creator_other', expected=404)
    self.get(f'/api/polls/{pid}', 'listener_test', expected=404)
    self.call('PUT', path, 'creator_test', {**body, 'question': 'Updated question'})
    detail = self.post(path + '/publish', 'creator_test')
    oid = detail['options'][0]['optionId']
    other_option = detail['options'][1]['optionId']
    self.get(base, 'creator_test')
    self.get(f"/api/creators/{self.ids['creator_testProfile']}/polls", 'listener_test')
    self.get(f'/api/polls/{pid}', 'listener_test')
    response_path = f'/api/polls/{pid}/responses'
    self.post(response_path, 'listener_test', {'optionId': oid}, expected=201)
    self.post(response_path, 'listener_test', {'optionId': oid}, expected=409)
    self.get(response_path + '/me', 'listener_test')
    self.call('PUT', response_path + '/me', 'listener_test', {'optionId': other_option})
    self.get(path + '/responses', 'creator_test')
    self.check(self.get(path + '/results', 'creator_test')['totalResponses'] == 1,
               'Aggregate result counts one response')
    self.get(f'/api/polls/{pid}/results', 'listener_test')
    self.call('DELETE', response_path + '/me', 'listener_test', expected=204)
    self.post(response_path, 'listener_test', {'optionId': oid}, expected=201)
    self.post(path + '/close', 'creator_test')
    self.call('PUT', response_path + '/me', 'listener_test', {'optionId': oid}, expected=409)
    self.call('DELETE', path, 'creator_test', expected=204)
    self.get(path, 'creator_test', expected=404)
    self.post(base, 'creator_test', {**body, 'options': ['A', 'a']}, expected=400)
    self.post(base, 'creator_test', {**body, 'podcastId': str(uuid.uuid4())}, expected=404)
    self.post(base, 'listener_test', body, expected=403)
    category = self.post('/api/admin/categories', 'admin_test',
                         {'name': 'Poll fixtures', 'slug': 'poll-fixtures', 'active': True}, expected=201)
    self.ids['categoryId'] = category['categoryId']
    sid = self.post('/api/creator/series', 'creator_test',
                    {'categoryId': category['categoryId'], 'title': 'Poll series', 'slug': 'poll-series'},
                    expected=201)['seriesId']
    podcast = self.create_podcast()
    for series_id, podcast_id in [(sid, None), (None, podcast), (sid, podcast)]:
        linked = self.post(base, 'creator_test', {**body, 'seriesId': series_id, 'podcastId': podcast_id}, expected=201)
        lid = linked['poll']['pollId']
        self.check(linked['poll']['seriesId'] == series_id and linked['poll']['podcastId'] == podcast_id,
                   'Optional content links are returned correctly')
        self.post(f'{base}/{lid}/publish', 'creator_test')
    listing = self.get(base + f'?seriesId={sid}&podcastId={podcast}', 'creator_test')
    self.check(len(listing['content']) == 1, 'Both content filters use AND')
    public = self.get(f"/api/creators/{self.ids['creator_testProfile']}/polls?podcastId={podcast}", 'listener_test')
    self.check(len(public['content']) == 2, 'Public listing filters podcast links')
    self.call('PUT', f'{base}/{lid}', 'creator_test', body, expected=409)
    race_path = f'/api/polls/{lid}/responses'
    race_option = linked['options'][0]['optionId']
    with ThreadPoolExecutor(2) as pool:
        list(pool.map(lambda _: self.post(race_path, 'listener_test', {'optionId': race_option}, expected=[201, 409]), range(2)))
    self.check(self.sql(f'''SELECT count(*) FROM "Poll_votes" WHERE poll_id='{lid}';''') == '1',
               'Concurrent submissions persist exactly one response')
    self.post(race_path, 'other_test', {'optionId': str(uuid.uuid4())}, expected=400)
    now = datetime.now(timezone.utc)
    future = self.post(base, 'creator_test', {**body, 'startsAt': (now + timedelta(days=1)).isoformat()}, expected=201)
    fid = future['poll']['pollId']
    self.post(f'{base}/{fid}/publish', 'creator_test')
    self.post(f'/api/polls/{fid}/responses', 'listener_test', {'optionId': future['options'][0]['optionId']}, expected=409)
    expired = self.post(base, 'creator_test', {**body, 'startsAt': (now - timedelta(days=2)).isoformat(),
                                            'endsAt': (now - timedelta(days=1)).isoformat()}, expected=201)
    self.post(f"{base}/{expired['poll']['pollId']}/publish", 'creator_test', expected=409)
    self.post(base, 'creator_test', {**body, 'startsAt': now.isoformat(), 'endsAt': now.isoformat()}, expected=400)


if __name__ == '__main__':
    suite.Regression.run = polls
    sys.exit(suite.main())
