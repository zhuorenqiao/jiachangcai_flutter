"""Browser acceptance check for the WeChat-style horizontal tab swipe.

Serves build/web over HTTP, drives a real Chromium/Edge, and swipes with the
mouse across the page centre. Verifies:
  * the tab actually changes,
  * the bottom navigation highlight follows,
  * swiping back returns to the previous tab,
  * no page errors / failed requests.

Run: python tools/check_swipe.py --browser <path-to-msedge|chrome>
"""
import argparse
import json
import re
from pathlib import Path

from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--url', default='http://127.0.0.1:8090')
parser.add_argument('--browser', default=None, help='executable path; omit to use channel msedge')
parser.add_argument('--report', default='docs/swipe-check.json')
args = parser.parse_args()

report = {'checks': [], 'pageErrors': [], 'failedRequests': [], 'steps': []}


def log(msg):
    print(msg, flush=True)
    report['steps'].append(msg)


def selected_tab(page):
    """Name of the bottom-bar tab that is currently selected, or None."""
    tabs = page.get_by_role('tab')
    for i in range(tabs.count()):
        t = tabs.nth(i)
        if t.get_attribute('aria-selected') == 'true':
            return (t.get_attribute('aria-label') or t.inner_text() or '').strip()
    return None


def enabled_semantics(page):
    if page.locator('flt-semantics-placeholder').count():
        page.locator('flt-semantics-placeholder').evaluate('(el)=>el.click()')
        page.wait_for_timeout(400)


def swipe(page, dx, steps=24):
    """Press at the centre and drag horizontally, mimicking a finger flick."""
    box = page.viewport_size
    cx, cy = box['width'] / 2, box['height'] / 2
    page.mouse.move(cx, cy)
    page.mouse.down()
    for i in range(1, steps + 1):
        page.mouse.move(cx + dx * i / steps, cy, steps=1)
        page.wait_for_timeout(8)
    page.mouse.up()
    page.wait_for_timeout(650)


with sync_playwright() as p:
    kwargs = {'headless': True}
    if args.browser:
        kwargs['executable_path'] = args.browser
    else:
        kwargs['channel'] = 'msedge'
    browser = p.chromium.launch(args=['--no-sandbox'], **kwargs)
    page = browser.new_page(viewport={'width': 390, 'height': 844})
    page.on('pageerror', lambda e: report['pageErrors'].append(str(e)))
    page.on('requestfailed', lambda r: report['failedRequests'].append(r.url))

    page.goto(args.url, wait_until='networkidle')
    enabled_semantics(page)

    # Log in.
    page.get_by_role('button', name='本机登录，开始点餐', exact=True).click()
    page.get_by_role('button', name='全部菜品', exact=True).wait_for()
    log('login -> home')
    start = selected_tab(page)
    log(f'initial selected tab = {start!r}')
    assert start and '首页' in start, f'expected 首页 selected, got {start!r}'
    page.screenshot(path='docs/shot-0-home.png')

    # 1) Swipe left: home -> menu.
    swipe(page, -320)
    after1 = selected_tab(page)
    has_menu = page.get_by_text('全部菜品').count() > 0 or page.get_by_text('本店分类').count() > 0
    log(f'after swipe left #1: selected={after1!r} menuContentVisible={has_menu}')
    assert after1 and '点餐' in after1, f'expected 点餐 after swipe, got {after1!r}'
    report['checks'].append('swipe left changes tab and nav highlight')
    page.screenshot(path='docs/shot-1-menu.png')

    # 2) Swipe left again: menu -> cart.
    swipe(page, -320)
    after2 = selected_tab(page)
    log(f'after swipe left #2: selected={after2!r}')
    assert after2 and '购物车' in after2, f'expected 购物车, got {after2!r}'
    report['checks'].append('second swipe advances to cart')
    page.screenshot(path='docs/shot-2-cart.png')

    # 3) Swipe right: cart -> menu (back the way we came).
    swipe(page, 320)
    after3 = selected_tab(page)
    log(f'after swipe right: selected={after3!r}')
    assert after3 and '点餐' in after3, f'expected 点餐, got {after3!r}'
    report['checks'].append('swipe right goes back')

    # 4) A mouse drag must not break the tap-based navigation either.
    page.get_by_role('tab', name=re.compile('我的')).click()
    page.wait_for_timeout(700)
    after4 = selected_tab(page)
    log(f'after tapping 我的: selected={after4!r}')
    assert after4 and '我的' in after4, f'expected 我的, got {after4!r}'
    report['checks'].append('tapping a destination still works after swiping')
    page.screenshot(path='docs/shot-3-profile.png')

    # 5) Vertical scrolling inside a page must still work (regression guard:
    #    enabling mouse drags on the pager must not capture list dragging).
    page.get_by_role('tab', name=re.compile('首页')).click()
    page.wait_for_timeout(700)
    box = page.viewport_size
    page.mouse.move(box['width'] / 2, box['height'] * 0.75)
    page.mouse.down()
    for i in range(20):
        page.mouse.move(box['width'] / 2, box['height'] * 0.75 - i * 12, steps=1)
        page.wait_for_timeout(8)
    page.mouse.up()
    page.wait_for_timeout(600)
    still_home = selected_tab(page)
    log(f'after vertical drag on home: selected={still_home!r}')
    assert still_home and '首页' in still_home, (
        f'vertical drag must not switch tabs, got {still_home!r}')
    report['checks'].append('vertical drag inside a page does not switch tabs')

    # 6) Tapping a category tile on the home page must open the menu page AND
    #    scroll the dish list down to that category. The sections used to be
    #    built lazily, so a category far down the list silently failed to scroll;
    #    the last tile exercises exactly that case.
    page.get_by_role('tab', name=re.compile('首页')).click()
    page.wait_for_timeout(700)
    tiles = page.get_by_text('饮品甜点')
    assert tiles.count() > 0, 'expected the 饮品甜点 category tile on the home page'
    tiles.first.click()
    page.wait_for_timeout(1200)
    on_menu = selected_tab(page)
    log(f'after tapping last category tile: selected={on_menu!r}')
    assert on_menu and '点餐' in on_menu, f'expected 点餐, got {on_menu!r}'

    # Its dish (a category only reachable by scrolling) must be on screen.
    dish = page.get_by_text('红豆沙小圆子')
    assert dish.count() > 0, 'expected the last category dish after the jump'
    dbox = dish.first.bounding_box()
    log(f'last-category dish bounding box = {dbox}')
    assert dbox is not None and 0 <= dbox['y'] < 844, (
        f'the jumped-to dish should be inside the viewport, got {dbox}')
    report['checks'].append('home category tile scrolls the menu to that category')
    page.screenshot(path='docs/shot-4-category-jump.png')

    assert not report['pageErrors'], report['pageErrors']
    assert not report['failedRequests'], report['failedRequests']
    browser.close()

Path(args.report).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k: report[k] for k in ('checks', 'pageErrors', 'failedRequests')},
                 ensure_ascii=False, indent=2))
