# "Hello How Are You?"
# Example wrapper that demonstrates the Human Intervention Point (HIP) feature.
#
# Pre-condition: SOFTFAB_API_LOGIN and SOFTFAB_API_PASSWD are defined as environment variables

from tkinter import *
from time import sleep

from urllib import request
from urllib.parse import urlparse, urljoin, urlencode
from urllib.request import urlopen
from base64 import standard_b64encode
from os import getenv

def setTaskAlert(alert):
	'''Performs the TaskAlert API call.
	Alert value "attention" starts a HIP, alert value "" (empty) ends a HIP.
	'''

	# Get credentials for API user from the calling environment
	sf_apiuser_login = getenv('SOFTFAB_API_LOGIN')
	sf_apiuser_passwd = getenv('SOFTFAB_API_PASSWD')

	if sf_apiuser_login is None:
		print('SOFTFAB_API_LOGIN is not defined as an environment variable')
		return False

	if sf_apiuser_passwd is None:
		print('SOFTFAB_API_PASSWD is not defined as an environment variable')
		return False

	# Add API call to URL
	url = urljoin(SF_CC_URL, 'TaskAlert')

	values = {
		'jobId' : SF_JOB_ID,
		'taskName': SF_TASK_ID,
		'alert' : alert
		}
	data = urlencode(values)
	data = data.encode('ascii') # data should be bytes

	# Perform HTTP POST
	req = request.Request(url, data) # this will make the method "POST"

	# Add authentication
	auth = '%s:%s' % (sf_apiuser_login, sf_apiuser_passwd)
	b64auth = standard_b64encode(auth.encode('ascii'))
	req.add_header('Authorization', 'Basic %s' % b64auth.decode('ascii'))

	with urlopen(req) as response:
		xml_response = response.read()
		encoding = response.headers.get_content_charset('UTF-8')

	decoded_xml = xml_response.decode(encoding)

	# TODO: parse decoded_xml as XML
	# TODO: in CC throw an error if the state of a task is not valid for receiving an alert. Proposal: throw IllegalStateError in setAlert() and catch in TaskAlert to generate an 400 error.

	return decoded_xml == '<ok/>'

class Dialog(Frame):
	'''Dialog that asks the user to enter a value.
	'''

	def __init__(self, title, prompt):
		Frame.__init__(self, None)
		self.master.title(title)

		prompt = Label(self, text = prompt, justify = LEFT)
		prompt.pack(side = TOP, fill = X, expand = True, padx = 5, pady = 1)

		self.entry = Entry(self, name = "entry", takefocus = True)
		self.entry.pack(side = TOP, fill = X, expand = True, padx = 5, pady = 5)
		self.entry.bind("<Return>", self.ok)
		self.entry.bind("<Escape>", self.cancel)

		okButton = Button(
			self, text = "OK", width = 10, command = self.ok, default = ACTIVE
			)
		okButton.pack(side = LEFT, padx = 5, pady = 5)
		okButton.bind("<Return>", self.ok)
		okButton.bind("<Escape>", self.cancel)

		cancelButton = Button(
			self, text = "Cancel", width = 10, command = self.cancel
			)
		cancelButton.pack(side = LEFT, padx = 5, pady = 5)
		cancelButton.bind("<Return>", self.cancel)
		cancelButton.bind("<Escape>", self.cancel)

		self.pack()
		self.bind("<Return>", self.ok)
		self.bind("<Escape>", self.cancel)
		self.initial_focus = self.entry
		self.initial_focus.focus_set()
		self.result = None

	def ok(self, event = None):
		self.result = self.entry.get()
		self.master.destroy()

	def cancel(self, event = None):
		self.master.destroy()

# Pretend we have a lot of work to do before we reach the HIP.
print('Do some work for 5 seconds.')
sleep(5)

if USER_NAME:
	# User name provided as a parameter; use it.
	result = 'ok'
	summary = 'Hello ' + USER_NAME + '!'
else:
	# No user name provided; ask for it.
	print('Start HIP.')
	if setTaskAlert('attention'):
		print('Open dialog.')
		window = Dialog('Hello', 'What is your name?')
		window.mainloop()
		print('Dialog returned: %s' % window.result)
		if window.result is None or window.result is '':
			result = 'warning'
			summary = 'User did not introduce himself'
		else:
			result = 'ok'
			summary = 'Hello ' + window.result + '!'
		print('End HIP.')
		setTaskAlert('')
	else:
		print('Could not start HIP.')
		result = 'error'
		summary = 'Could not start HIP!'

# Write results file.
resfile = open(SF_RESULTS, 'w')
resfile.write('result=%s\n' % result)
resfile.write('summary=%s\n' % summary)
resfile.close()
