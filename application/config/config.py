class Config(object):
    DEBUG = False
    TESTING = False
    DB_SERVER = 'xxx.xxx.xxx.xxx'
    DB_USER = 'user'
    SQLALCHEMY_TRACK_MODIFICATIONS = True
    EXPLAIN_TEMPLATE_LOADING = False

    @property
    def SQLALCHEMY_DATABASE_URI(self):
        return f'mysql://{self.DB_USER}@{self.DB_SERVER}/you-todoo'


class ProductionConfig(Config):
    DB_SERVER = 'localhost'


class DevelopmentConfig(Config):
    DB_SERVER = 'localhost'
    DEBUG = True


class TestingConfig(Config):
    DB_SERVER = 'localhost'
    DEBUG = True
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    EXPLAIN_TEMPLATE_LOADING = True
    # SQLALCHEMY_DATABASE_URI = 'sqlite:///test.db'
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
