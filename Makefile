
PREFIX := /usr

install:
	install -D tf_worker $(PREFIX)/libexec/tf_worker
	install -D tf_server $(PREFIX)/libexec/tf_server
