#https://gist.github.com/julionc/7476620
import time
import sys
import json
filename = sys.argv[1]
package = json.loads(open(filename).read())
tweet = package['tweet']
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.keys import Keys
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
chrome_options = Options()
chrome_options.add_argument('--headless')
chrome_options.add_argument('--no-sandbox')
chrome_options.add_argument('--disable-dev-shm-usage')
chrome_options.add_argument('window-size=1200x600')
driver = webdriver.Chrome(chrome_options=chrome_options)
# driver.set_window_size(1000,1000)
driver.get("http://twitter.com/login")
print(".")
time.sleep(10)
driver.get_screenshot_as_file('login_page.png')
username = driver.find_element_by_class_name("js-username-field")
username.click()
username.send_keys(package["username"])
time.sleep(2)
password = driver.find_element_by_class_name("js-password-field")
password.click()
password.send_keys(package["password"])
driver.get_screenshot_as_file('login_filled.png')
password.submit()
print("..")
time.sleep(8)
driver.get_screenshot_as_file('home.png')
actions = ActionChains(driver)
actions = actions.send_keys("N")
actions = actions.send_keys(tweet)
actions.perform()
time.sleep(8)
actions = ActionChains(driver)
actions = actions.send_keys(Keys.CONTROL + Keys.ENTER)
actions.perform()

driver.get_screenshot_as_file('send_tweet.png')
# driver.find_elements_by_tag_name("button")
print("...")
driver.get_screenshot_as_file('tweet_sent.png')
driver.close()
print("success")
