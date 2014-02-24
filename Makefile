BASE_DIR = $(shell pwd)
REBAR := $(BASE_DIR)/rebar
DIALYZER := dialyzer
DIALYZER_APPS := kernel stdlib sasl inets crypto public_key ssl
DEPS := deps
BIN := $(BASE_DIR)/bin
APP := ploutos
SERVICE := $(subst _,-,$(APP))

OVERLAY_VARS    ?=

BASIC_PLT := $(APP).plt

.PHONY: all clean xref docs lock-deps 

all: app

app: $(REBAR) deps
	@$(REBAR) compile

deps: $(REBAR) 
	@$(REBAR) get-deps

clean: $(REBAR)
	@$(REBAR) clean


rel: app rel/$(APP) 

rel/$(APP):
	@$(REBAR) generate $(OVERLAY_VARS)

relclean:
	@rm -rf rel/$(APP)

$(BASIC_PLT): build-plt

build-plt: 
	@$(DIALYZER) --build_plt --output_plt $(BASIC_PLT) --apps $(DIALYZER_APPS)

dialyze: $(BASIC_PLT)
	@$(DIALYZER) -r src deps/*/src --no_native --src --plt $(BASIC_PLT) -Werror_handling \
		-Wrace_conditions -Wunmatched_returns # -Wunderspecs

xref: $(REBAR) clean app
	@$(REBAR) xref skip_deps=true


$(DEPS)/rebar:
	@mkdir -p $(DEPS)
	git clone https://github.com/rebar/rebar.git $(DEPS)/rebar

$(REBAR): $(DEPS)/rebar
	$(MAKE) -C $(DEPS)/rebar
	cp $(DEPS)/rebar/rebar .

PREFIX := /usr/lib
LOG_DIR := /var/log/$(APP)
VAR_DIR := /var/lib/$(APP)
USER := ploutos

install: relclean rel uninstall
	cp -R rel/$(APP) $(PREFIX)/
	ln -s $(PREFIX)/$(APP)/log $(LOG_DIR)
	ln -s $(PREFIX)/$(APP)/etc $(VAR_DIR)
	ver=`cat $(PREFIX)/$(APP)/releases/start_erl.data | awk '{print $$2}'`;\
		ln -s $(PREFIX)/$(APP)/releases/$$ver /etc/$(APP)
	chown -R $(USER) $(PREFIX)/$(APP) $(LOG_DIR) /etc/$(APP)
	ln -sf $(PREFIX)/$(APP)/bin/$(APP) /usr/bin/$(APP)

uninstall:
	rm -rf $(PREFIX)/$(APP) \
		$(LOG_DIR) \
		$(VAR_DIR) \
		/etc/$(APP) \
		/usr/bin/$(APP)
