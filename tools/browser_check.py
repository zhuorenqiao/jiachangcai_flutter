"""Browser acceptance check. Run after serving build/web on localhost:5173.
Requires: python3 -m pip install playwright; use --browser for local Chromium.
"""
import argparse
import json
import re
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

parser = argparse.ArgumentParser()
parser.add_argument('--url', default='http://127.0.0.1:5173')
parser.add_argument('--browser', default='/usr/local/bin/chromium')
parser.add_argument('--report', default='/tmp/jcc-browser-check.json')
args = parser.parse_args()
report = {'checks': [], 'pageErrors': [], 'failedRequests': []}
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=args.browser, headless=True, args=['--no-sandbox'])
    page = browser.new_page(viewport={'width':390,'height':844})
    page.on('pageerror', lambda error: report['pageErrors'].append(str(error)))
    page.on('requestfailed', lambda req: report['failedRequests'].append(req.url))
    page.goto(args.url, wait_until='networkidle')
    page.locator('flt-semantics-placeholder').evaluate('(element)=>element.click()')
    page.get_by_role('button', name='本机登录，开始点餐', exact=True).click()
    page.get_by_role('button', name='全部菜品', exact=True).wait_for()
    report['checks'].append('login and home')
    page.screenshot(path='/tmp/jcc-review-home.png')
    page.get_by_role('button', name='添加农家小炒肉', exact=True).click()
    page.get_by_role('tab', name=re.compile('购物车')).click()
    page.get_by_role('button', name='提交订单', exact=True).wait_for()
    report['checks'].append('cart add and live total')
    page.get_by_role('button', name='提交订单', exact=True).click()
    page.get_by_role('button', name='确定', exact=True).click()
    order = page.get_by_role('group', name=re.compile(r'^订单 [\s\S]*待完成'))
    page.wait_for_timeout(500)
    order.wait_for()
    report['checks'].append('checkout and pending order')
    order.click()
    page.get_by_role('button', name='确认完成', exact=True).click()
    page.get_by_role('button', name='确定', exact=True).click()
    page.get_by_role('button', name='再来一单', exact=True).click()
    page.get_by_role('button', name='提交订单', exact=True).wait_for()
    report['checks'].append('complete and reorder')
    page.reload(wait_until='networkidle')
    if page.locator('flt-semantics-placeholder').count():
        page.locator('flt-semantics-placeholder').evaluate('(element)=>element.click()')
    page.get_by_role('tab', name=re.compile('购物车')).click()
    page.get_by_role('button', name='提交订单', exact=True).wait_for()
    report['checks'].append('reload restores session and cart')
    page.get_by_role('tab', name='我的', exact=True).click()
    page.get_by_role('button', name=re.compile('菜品管理')).click()
    page.get_by_role('button', name='新增菜品', exact=True).wait_for()
    report['checks'].append('profile and dish management')
    page.screenshot(path='/tmp/jcc-review-admin.png')
    assert not report['pageErrors'], report['pageErrors']
    browser.close()
Path(args.report).write_text(json.dumps(report, ensure_ascii=False, indent=2))
print(json.dumps(report, ensure_ascii=False, indent=2))
