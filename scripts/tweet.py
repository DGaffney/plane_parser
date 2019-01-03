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
driver = webdriver.Chrome(chrome_options=chrome_options)
driver.get("http://twitter.com/login")
time.sleep(5)
username = driver.find_element_by_class_name("js-username-field")
username.click()
username.send_keys(package["username"])
password = driver.find_element_by_class_name("js-password-field")
password.click()
password.send_keys(package["password"])
password.submit()
time.sleep(5)
actions = ActionChains(driver)
actions = actions.send_keys("N")
actions = actions.send_keys(tweet)
actions = actions.send_keys(Keys.TAB)
actions = actions.send_keys(Keys.TAB)
actions = actions.send_keys(Keys.TAB)
actions = actions.send_keys(Keys.TAB)
actions = actions.send_keys(Keys.TAB)
actions = actions.send_keys(Keys.TAB)
actions = actions.send_keys(Keys.TAB)
actions = actions.send_keys(Keys.TAB)
actions = actions.send_keys(Keys.ENTER)
actions.perform()
time.sleep(2)
button = driver.find_element_by_class_name("SendTweetsButton")
button.click()
driver.close()
print("success")
